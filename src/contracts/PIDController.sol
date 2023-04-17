// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Math, WAD, RAY} from '@libraries/Math.sol';
import {Authorizable} from '@contract-utils/Authorizable.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';

/**
 * @title PIDController
 * @notice Redemption Rate Feedback Mechanism (RRFM) controller that implements a PI controller
 */
contract PIDController is IPIDController, Authorizable {
  using Math for uint256;
  using Math for int256;

  constructor(
    int256 Kp_,
    int256 Ki_,
    uint256 perSecondCumulativeLeak_,
    uint256 integralPeriodSize_,
    uint256 noiseBarrier_,
    uint256 feedbackOutputUpperBound_,
    int256 feedbackOutputLowerBound_,
    int256[] memory importedState
  ) {
    require(
      feedbackOutputUpperBound_ < ((type(uint256).max - defaultRedemptionRate) - 1) && feedbackOutputUpperBound_ > 0,
      'PIDController/invalid-foub'
    );
    require(
      feedbackOutputLowerBound_ < 0 && feedbackOutputLowerBound_ >= -int256(NEGATIVE_RATE_LIMIT),
      'PIDController/invalid-folb'
    );
    require(integralPeriodSize_ > 0, 'PIDController/invalid-ips');
    require(noiseBarrier_ > 0 && noiseBarrier_ <= WAD, 'PIDController/invalid-nb');
    require(Math.absolute(Kp_) <= WAD && Math.absolute(Ki_) <= WAD, 'PIDController/invalid-sg');

    _addAuthorization(msg.sender);

    feedbackOutputUpperBound = feedbackOutputUpperBound_;
    feedbackOutputLowerBound = feedbackOutputLowerBound_;
    integralPeriodSize = integralPeriodSize_;
    controllerGains = ControllerGains(Kp_, Ki_);
    perSecondCumulativeLeak = perSecondCumulativeLeak_;
    noiseBarrier = noiseBarrier_;

    if (importedState.length > 0) {
      require(uint256(importedState[0]) <= block.timestamp, 'PIDController/invalid-imported-time');
      priceDeviationCumulative = importedState[3];
      lastUpdateTime = uint256(importedState[0]);
      if (importedState[4] > 0) {
        deviationObservations.push(DeviationObservation(uint256(importedState[4]), importedState[1], importedState[2]));
      }

      historicalCumulativeDeviations.push(priceDeviationCumulative);
    }
  }

  // The address allowed to call calculateRate
  address public seedProposer;

  // --- Fluctuating/Dynamic Variables ---
  // Array of observations storing the latest timestamp as well as the proportional and integral terms
  DeviationObservation[] internal deviationObservations;
  // Array of historical priceDeviationCumulative
  int256[] internal historicalCumulativeDeviations;

  // -- Static & Default Variables ---
  // The Kp and Ki values used in this calculator
  ControllerGains internal controllerGains;

  // The minimum percentage deviation from the redemption price that allows the contract to calculate a non null redemption rate
  uint256 internal noiseBarrier; // [WAD]
  // The default redemption rate to calculate in case P + I is smaller than noiseBarrier
  uint256 internal defaultRedemptionRate = RAY; // [RAY]
  // The maximum value allowed for the redemption rate
  uint256 internal feedbackOutputUpperBound; // [RAY]
  // The minimum value allowed for the redemption rate
  int256 internal feedbackOutputLowerBound; // [RAY]

  // Flag indicating that the rate computed is per second
  uint256 internal constant defaultGlobalTimeline = 1;

  uint256 internal constant NEGATIVE_RATE_LIMIT = RAY - 1;

  // The integral term (sum of deviations at each calculateRate call minus the leak applied at every call)
  int256 internal priceDeviationCumulative; // [RAY]
  // The per second leak applied to priceDeviationCumulative before the latest deviation is added
  uint256 internal perSecondCumulativeLeak; // [RAY]
  // Timestamp of the last update
  uint256 internal lastUpdateTime; // [timestamp]
  // The minimum delay between two computeRate calls
  uint256 internal integralPeriodSize; // [seconds]

  /**
   * @notice Return a redemption rate bounded by feedbackOutputLowerBound and feedbackOutputUpperBound as well as the
   *             timeline over which that rate will take effect
   * @param piOutput The raw redemption rate computed from the proportional and integral terms
   */
  function getBoundedRedemptionRate(int256 piOutput) public view returns (uint256, uint256) {
    uint256 newRedemptionRate;

    int256 boundedPIOutput = _getBoundedPIOutput(piOutput);

    // newRedemptionRate cannot be lower than 10^0 (1) because of the way rpower is designed
    bool negativeOutputExceedsHundred = (boundedPIOutput < 0 && -boundedPIOutput >= int256(defaultRedemptionRate));

    // If it is smaller than 1, set it to the nagative rate limit
    if (negativeOutputExceedsHundred) {
      newRedemptionRate = NEGATIVE_RATE_LIMIT;
    } else {
      // If boundedPIOutput is lower than -int(NEGATIVE_RATE_LIMIT) set newRedemptionRate to 1
      if (boundedPIOutput < 0 && boundedPIOutput <= -int256(NEGATIVE_RATE_LIMIT)) {
        newRedemptionRate = uint256((int256(defaultRedemptionRate) - int256(NEGATIVE_RATE_LIMIT)));
      } else {
        // Otherwise add defaultRedemptionRate and boundedPIOutput together
        newRedemptionRate = uint256((int256(defaultRedemptionRate) + boundedPIOutput));
      }
    }

    return (newRedemptionRate, defaultGlobalTimeline);
  }

  /**
   * @dev Using virtual method to simulate BasicPIDController
   */
  function _getBoundedPIOutput(int256 _piOutput) internal view virtual returns (int256 _boundedPIOutput) {
    _boundedPIOutput = _piOutput;
    if (_piOutput < feedbackOutputLowerBound) {
      _boundedPIOutput = feedbackOutputLowerBound;
    } else if (_piOutput > int256(feedbackOutputUpperBound)) {
      _boundedPIOutput = int256(feedbackOutputUpperBound);
    }
  }

  // --- Rate Validation/Calculation ---
  /**
   * @notice Compute a new redemption rate
   * @param marketPrice The system coin market price
   * @param redemptionPrice The system coin redemption price
   * @param accumulatedLeak The total leak that will be applied to priceDeviationCumulative (the integral) before the latest
   *        proportional term is added
   */
  function computeRate(
    uint256 marketPrice,
    uint256 redemptionPrice,
    uint256 accumulatedLeak
  ) external returns (uint256) {
    require(msg.sender == seedProposer, 'PIDController/only-seed-proposer');

    // Ensure that at least integralPeriodSize seconds passed since the last update or that this is the first update
    require((block.timestamp - lastUpdateTime) >= integralPeriodSize || lastUpdateTime == 0, 'PIDController/wait-more');

    int256 proportionalTerm = _getProportionalTerm(marketPrice, redemptionPrice);

    // Update the integral term by passing the proportional (current deviation) and the total leak that will be applied to the integral
    updateDeviationHistory(proportionalTerm, accumulatedLeak);
    // Set the last update time to now
    lastUpdateTime = block.timestamp;
    // Multiply P by Kp and I by Ki and then sum P & I in order to return the result
    int256 piOutput = getGainAdjustedPIOutput(proportionalTerm, priceDeviationCumulative);
    // If the P * Kp + I * Ki output breaks the noise barrier, you can recompute a non null rate. Also make sure the sum is not null
    if (breaksNoiseBarrier(Math.absolute(piOutput), redemptionPrice) && piOutput != 0) {
      // Get the new redemption rate by taking into account the feedbackOutputUpperBound and feedbackOutputLowerBound
      (uint256 newRedemptionRate,) = getBoundedRedemptionRate(piOutput);
      return newRedemptionRate;
    } else {
      return RAY;
    }
  }

  /**
   * @dev Using virtual method to simulate RawPIDController
   */
  function _getProportionalTerm(
    uint256 marketPrice,
    uint256 redemptionPrice
  ) internal view virtual returns (int256 _proportionalTerm) {
    // Scale the market price by 10^9 so it also has 27 decimals like the redemption price
    uint256 scaledMarketPrice = (marketPrice * 1e9);

    // Calculate the proportional term as (redemptionPrice - marketPrice) * RAY / redemptionPrice
    _proportionalTerm = redemptionPrice.sub(scaledMarketPrice).rdiv(int256(redemptionPrice));

    return _proportionalTerm;
  }

  /**
   * @notice Returns whether the P + I sum exceeds the noise barrier
   * @param piSum Represents a sum between P + I
   * @param redemptionPrice The system coin redemption price
   */
  function breaksNoiseBarrier(uint256 piSum, uint256 redemptionPrice) public view virtual returns (bool) {
    uint256 deltaNoise = ((uint256(2) * WAD) - noiseBarrier);
    return piSum >= redemptionPrice.wmul(deltaNoise) - redemptionPrice;
  }

  /**
   * @notice Apply Kp to the proportional term and Ki to the integral term (by multiplication) and then sum P and I
   * @param proportionalTerm The proportional term
   * @param integralTerm The integral term
   */
  function getGainAdjustedPIOutput(int256 proportionalTerm, int256 integralTerm) public view returns (int256) {
    (int256 adjustedProportional, int256 adjustedIntegral) = getGainAdjustedTerms(proportionalTerm, integralTerm);
    return (adjustedProportional + adjustedIntegral);
  }

  /**
   * @notice Independently return and calculate P * Kp and I * Ki
   * @param proportionalTerm The proportional term
   * @param integralTerm The integral term
   */
  function getGainAdjustedTerms(int256 proportionalTerm, int256 integralTerm) public view returns (int256, int256) {
    return (controllerGains.Kp.wmul(proportionalTerm), controllerGains.Ki.wmul(integralTerm));
  }

  /**
   * @notice Push new observations in deviationObservations & historicalCumulativeDeviations while also updating priceDeviationCumulative
   * @param proportionalTerm The proportionalTerm
   * @param accumulatedLeak The total leak (similar to a negative interest rate) applied to priceDeviationCumulative before proportionalTerm is added to it
   */
  function updateDeviationHistory(int256 proportionalTerm, uint256 accumulatedLeak) internal {
    (int256 virtualDeviationCumulative,) = getNextPriceDeviationCumulative(proportionalTerm, accumulatedLeak);
    priceDeviationCumulative = virtualDeviationCumulative;
    historicalCumulativeDeviations.push(priceDeviationCumulative);
    deviationObservations.push(DeviationObservation(block.timestamp, proportionalTerm, priceDeviationCumulative));
  }

  /**
   * @notice Compute a new priceDeviationCumulative (integral term)
   * @param proportionalTerm The proportional term (redemptionPrice - marketPrice)
   * @param accumulatedLeak The total leak applied to priceDeviationCumulative before it is summed with the new time adjusted deviation
   */
  function getNextPriceDeviationCumulative(
    int256 proportionalTerm,
    uint256 accumulatedLeak
  ) public view returns (int256, int256) {
    int256 lastProportionalTerm = getLastProportionalTerm();
    uint256 timeElapsed = lastUpdateTime == 0 ? 0 : (block.timestamp - lastUpdateTime);
    int256 newTimeAdjustedDeviation = int256(proportionalTerm).riemannSum(lastProportionalTerm) * int256(timeElapsed);
    int256 leakedPriceCumulative = accumulatedLeak.rmul(priceDeviationCumulative);

    return ((leakedPriceCumulative + newTimeAdjustedDeviation), newTimeAdjustedDeviation);
  }

  /**
   * @notice Compute and return the upcoming redemption rate
   * @param marketPrice The system coin market price
   * @param redemptionPrice The system coin redemption price
   * @param accumulatedLeak The total leak applied to priceDeviationCumulative before it is summed with the proportionalTerm
   */
  function getNextRedemptionRate(
    uint256 marketPrice,
    uint256 redemptionPrice,
    uint256 accumulatedLeak
  ) public view returns (uint256, int256, int256, uint256) {
    int256 proportionalTerm = _getProportionalTerm(marketPrice, redemptionPrice);
    (int256 cumulativeDeviation,) = getNextPriceDeviationCumulative(proportionalTerm, accumulatedLeak);
    int256 piOutput = getGainAdjustedPIOutput(proportionalTerm, cumulativeDeviation);
    if (breaksNoiseBarrier(Math.absolute(piOutput), redemptionPrice) && piOutput != 0) {
      (uint256 newRedemptionRate, uint256 rateTimeline) = getBoundedRedemptionRate(piOutput);
      return (newRedemptionRate, proportionalTerm, cumulativeDeviation, rateTimeline);
    } else {
      return (RAY, proportionalTerm, cumulativeDeviation, defaultGlobalTimeline);
    }
  }

  /**
   * @notice Return the last proportional term stored in deviationObservations
   */
  function getLastProportionalTerm() public view returns (int256) {
    if (oll() == 0) return 0;
    return deviationObservations[oll() - 1].proportional;
  }

  /**
   * @notice Return the last integral term stored in deviationObservations
   */
  function getLastIntegralTerm() external view returns (int256) {
    if (oll() == 0) return 0;
    return deviationObservations[oll() - 1].integral;
  }

  /**
   * @notice Return the length of deviationObservations
   */
  function oll() public view returns (uint256) {
    return deviationObservations.length;
  }

  // --- Parameter Getters ---
  /**
   * @notice Get the timeline over which the computed redemption rate takes effect e.g rateTimeline = 3600 so the rate is
   *         computed over 1 hour
   */
  function rt(uint256 marketPrice, uint256 redemptionPrice, uint256) external view returns (uint256) {
    (,,, uint256 rateTimeline) = getNextRedemptionRate(marketPrice, redemptionPrice, 0);
    return rateTimeline;
  }

  /**
   * @notice Return Kp
   */
  function sg() external view returns (int256) {
    return controllerGains.Kp;
  }

  /**
   * @notice Return Ki
   */
  function ag() external view returns (int256) {
    return controllerGains.Ki;
  }

  function nb() external view returns (uint256) {
    return noiseBarrier;
  }

  function drr() external view returns (uint256) {
    return defaultRedemptionRate;
  }

  function foub() external view returns (uint256) {
    return feedbackOutputUpperBound;
  }

  function folb() external view returns (int256) {
    return feedbackOutputLowerBound;
  }

  function ps() external view returns (uint256) {
    return integralPeriodSize;
  }

  // TODO: replace for ps()
  function ips() external view returns (uint256) {
    return integralPeriodSize;
  }

  function pscl() external view returns (uint256) {
    return perSecondCumulativeLeak;
  }

  function lut() external view returns (uint256) {
    return lastUpdateTime;
  }

  function dgt() external view returns (uint256) {
    return defaultGlobalTimeline;
  }

  /**
   * @notice Returns the time elapsed since the last calculateRate call minus periodSize
   */
  function adat() external view returns (uint256) {
    uint256 elapsed = (block.timestamp - lastUpdateTime);
    if (elapsed < integralPeriodSize) {
      return 0;
    }
    return (elapsed - integralPeriodSize);
  }

  function pdc() external view returns (int256) {
    return priceDeviationCumulative;
  }

  /**
   * @notice Returns the time elapsed since the last calculateRate call
   */
  function tlv() external view returns (uint256) {
    uint256 elapsed = (lastUpdateTime == 0) ? 0 : (block.timestamp - lastUpdateTime);
    return elapsed;
  }

  /**
   * @notice Return the data from a deviation observation
   */
  function dos(uint256 i) external view returns (uint256, int256, int256) {
    return
      (deviationObservations[i].timestamp, deviationObservations[i].proportional, deviationObservations[i].integral);
  }

  function hcd(uint256 i) external view returns (int256) {
    return historicalCumulativeDeviations[i];
  }

  // --- Administration ---
  /**
   * @notice Modify an address parameter
   * @param parameter The name of the address parameter to change
   * @param addr The new address for the parameter
   */
  function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
    if (parameter == 'seedProposer') {
      seedProposer = addr;
    } else {
      revert('PIDController/modify-unrecognized-param');
    }
  }

  /**
   * @notice Modify an uint256 parameter
   * @param parameter The name of the parameter to change
   * @param val The new value for the parameter
   */
  function modifyParameters(bytes32 parameter, uint256 val) external isAuthorized {
    if (parameter == 'nb') {
      require(val > 0 && val <= WAD, 'PIDController/invalid-nb');
      noiseBarrier = val;
    } else if (parameter == 'ips') {
      require(val > 0, 'PIDController/null-ips');
      integralPeriodSize = val;
    } else if (parameter == 'ps') {
      // NOTE: keeping both for backwards compatibility with periodSize
      require(val > 0, 'PIDController/null-ips');
      integralPeriodSize = val;
    } else if (parameter == 'foub') {
      require(val < ((type(uint256).max - defaultRedemptionRate) - 1) && val > 0, 'PIDController/invalid-foub');
      feedbackOutputUpperBound = val;
    } else if (parameter == 'pscl') {
      require(val <= RAY, 'PIDController/invalid-pscl');
      perSecondCumulativeLeak = val;
    } else {
      revert('PIDController/modify-unrecognized-param');
    }
  }

  /**
   * @notice Modify an int256 parameter
   * @param parameter The name of the parameter to change
   * @param val The new value for the parameter
   */
  function modifyParameters(bytes32 parameter, int256 val) external isAuthorized {
    if (parameter == 'folb') {
      require(val < 0 && val >= -int256(NEGATIVE_RATE_LIMIT), 'PIDController/invalid-folb');
      feedbackOutputLowerBound = val;
    } else if (parameter == 'sg') {
      require(val >= -int256(WAD) && val <= int256(WAD), 'PIDController/invalid-sg');
      controllerGains.Kp = val;
    } else if (parameter == 'ag') {
      require(val >= -int256(WAD) && val <= int256(WAD), 'PIDController/invalid-ag');
      controllerGains.Ki = val;
    } else if (parameter == 'pdc') {
      require(controllerGains.Ki == 0, 'PIDController/cannot-set-pdc');
      priceDeviationCumulative = val;
    } else {
      revert('PIDController/modify-unrecognized-param');
    }
  }
}
