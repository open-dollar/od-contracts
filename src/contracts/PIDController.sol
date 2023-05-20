// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Math, WAD, RAY} from '@libraries/Math.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';

/**
 * @title PIDController
 * @notice Redemption Rate Feedback Mechanism (RRFM) controller that implements a PI controller
 */
contract PIDController is Authorizable, IPIDController {
  using Math for uint256;
  using Math for int256;

  uint256 internal constant _NEGATIVE_RATE_LIMIT = RAY - 1;
  uint256 internal constant _POSITIVE_RATE_LIMIT = type(uint256).max - RAY - 1;

  // The address allowed to call computeRate
  address public seedProposer;

  // --- Fluctuating/Dynamic Variables ---
  // Array of observations storing the latest timestamp as well as the proportional and integral terms
  DeviationObservation[] public deviationObservations;
  // Array of historical priceDeviationCumulative
  int256[] public historicalCumulativeDeviations;

  // -- Static & Default Variables ---
  // The Kp and Ki values used in this calculator
  ControllerGains internal _controllerGains;

  // The minimum percentage deviation from the redemption price that allows the contract to calculate a non null redemption rate
  uint256 public noiseBarrier; // [WAD]
  // The default redemption rate to calculate in case P + I is smaller than noiseBarrier, default redemption rate is RAY
  // The maximum value allowed for the redemption rate
  uint256 public feedbackOutputUpperBound; // [RAY]
  // The minimum value allowed for the redemption rate
  int256 public feedbackOutputLowerBound; // [RAY]
  // The integral term (sum of deviations at each computeRate call minus the leak applied at every call)
  int256 public priceDeviationCumulative; // [RAY]
  // The per second leak applied to priceDeviationCumulative before the latest deviation is added
  uint256 public perSecondCumulativeLeak; // [RAY]
  // Timestamp of the last update
  uint256 public lastUpdateTime; // [timestamp]
  // The minimum delay between two computeRate calls
  uint256 public integralPeriodSize; // [seconds]

  constructor(
    int256 _Kp,
    int256 _Ki,
    uint256 _perSecondCumulativeLeak,
    uint256 _integralPeriodSize,
    uint256 _noiseBarrier,
    uint256 _feedbackOutputUpperBound,
    int256 _feedbackOutputLowerBound,
    int256[] memory _importedState // TODO: replace for struct
  ) Authorizable(msg.sender) {
    require(
      _feedbackOutputUpperBound < _POSITIVE_RATE_LIMIT && _feedbackOutputUpperBound > 0,
      'PIDController/invalid-feedbackOutputUpperBound'
    );
    require(
      _feedbackOutputLowerBound < 0 && _feedbackOutputLowerBound >= -int256(_NEGATIVE_RATE_LIMIT),
      'PIDController/invalid-feedbackOutputLowerBound'
    );
    require(_integralPeriodSize > 0, 'PIDController/invalid-integralPeriodSize');
    require(_noiseBarrier > 0 && _noiseBarrier <= WAD, 'PIDController/invalid-noiseBarrier');
    require(Math.absolute(_Kp) <= WAD && Math.absolute(_Ki) <= WAD, 'PIDController/invalid-sg');

    feedbackOutputUpperBound = _feedbackOutputUpperBound;
    feedbackOutputLowerBound = _feedbackOutputLowerBound;
    integralPeriodSize = _integralPeriodSize;
    _controllerGains = ControllerGains(_Kp, _Ki);
    perSecondCumulativeLeak = _perSecondCumulativeLeak;
    noiseBarrier = _noiseBarrier;

    if (_importedState.length > 0) {
      require(uint256(_importedState[0]) <= block.timestamp, 'PIDController/invalid-imported-time');
      priceDeviationCumulative = _importedState[3];
      lastUpdateTime = uint256(_importedState[0]);
      if (_importedState[4] > 0) {
        deviationObservations.push(
          DeviationObservation(uint256(_importedState[4]), _importedState[1], _importedState[2])
        );
      }

      historicalCumulativeDeviations.push(priceDeviationCumulative);
    }
  }

  function controllerGains() external view returns (ControllerGains memory _cGains) {
    return _controllerGains;
  }

  /**
   * @notice Return a redemption rate bounded by feedbackOutputLowerBound and feedbackOutputUpperBound as well as the
   *             timeline over which that rate will take effect
   * @param  _piOutput The raw redemption rate computed from the proportional and integral terms
   */
  function getBoundedRedemptionRate(int256 _piOutput) external view returns (uint256 _newRedemptionRate) {
    return _getBoundedRedemptionRate(_piOutput);
  }

  function _getBoundedRedemptionRate(int256 _piOutput) internal view virtual returns (uint256 _newRedemptionRate) {
    int256 _boundedPIOutput = _getBoundedPIOutput(_piOutput);

    // feedbackOutputLowerBound will never be less than NEGATIVE_RATE_LIMIT : RAY - 1,
    // and feedbackOutputUpperBound will never be greater than POSITIVE_RATE_LIMIT : type(uint256).max - RAY - 1
    // boundedPIOutput can be safely added to RAY
    _newRedemptionRate = _boundedPIOutput < -int256(RAY) ? _NEGATIVE_RATE_LIMIT : RAY.add(_boundedPIOutput);

    return _newRedemptionRate;
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
    return _boundedPIOutput;
  }

  // --- Rate Validation/Calculation ---
  /**
   * @notice Compute a new redemption rate
   * @param  _marketPrice The system coin market price
   * @param  _redemptionPrice The system coin redemption price
   * @param  _accumulatedLeak The total leak that will be applied to priceDeviationCumulative (the integral) before the latest
   *        proportional term is added
   */
  function computeRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external returns (uint256 _newRedemptionRate) {
    require(msg.sender == seedProposer, 'PIDController/only-seed-proposer');

    // Ensure that at least integralPeriodSize seconds passed since the last update or that this is the first update
    require((block.timestamp - lastUpdateTime) >= integralPeriodSize || lastUpdateTime == 0, 'PIDController/wait-more');
    int256 _proportionalTerm = _getProportionalTerm(_marketPrice, _redemptionPrice);

    // Update the integral term by passing the proportional (current deviation) and the total leak that will be applied to the integral
    _updateDeviationHistory(_proportionalTerm, _accumulatedLeak);

    // Set the last update time to now
    lastUpdateTime = block.timestamp;
    // Multiply P by Kp and I by Ki and then sum P & I in order to return the result
    int256 _piOutput = _getGainAdjustedPIOutput(_proportionalTerm, priceDeviationCumulative);
    // If the P * Kp + I * Ki output breaks the noise barrier, you can recompute a non null rate. Also make sure the sum is not null
    if (_breaksNoiseBarrier(Math.absolute(_piOutput), _redemptionPrice) && _piOutput != 0) {
      // Get the new redemption rate by taking into account the feedbackOutputUpperBound and feedbackOutputLowerBound
      _newRedemptionRate = _getBoundedRedemptionRate(_piOutput);
      return _newRedemptionRate;
    } else {
      return RAY;
    }
  }

  /**
   * @dev Using virtual method to simulate RawPIDController
   */
  function _getProportionalTerm(
    uint256 _marketPrice,
    uint256 _redemptionPrice
  ) internal view virtual returns (int256 _proportionalTerm) {
    // Scale the market price by 10^9 so it also has 27 decimals like the redemption price
    uint256 _scaledMarketPrice = _marketPrice * 1e9;

    // Calculate the proportional term as (redemptionPrice - marketPrice) * RAY / redemptionPrice
    _proportionalTerm = _redemptionPrice.sub(_scaledMarketPrice).rdiv(int256(_redemptionPrice));

    return _proportionalTerm;
  }

  /**
   * @notice Returns whether the P + I sum exceeds the noise barrier
   * @param  _piSum Represents a sum between P + I
   * @param  _redemptionPrice The system coin redemption price
   */
  function breaksNoiseBarrier(uint256 _piSum, uint256 _redemptionPrice) external view virtual returns (bool _breaksNb) {
    return _breaksNoiseBarrier(_piSum, _redemptionPrice);
  }

  function _breaksNoiseBarrier(uint256 _piSum, uint256 _redemptionPrice) internal view virtual returns (bool _breaksNb) {
    uint256 _deltaNoise = 2 * WAD - noiseBarrier;
    return _piSum >= _redemptionPrice.wmul(_deltaNoise) - _redemptionPrice;
  }

  /**
   * @notice Apply Kp to the proportional term and Ki to the integral term (by multiplication) and then sum P and I
   * @param  _proportionalTerm The proportional term
   * @param  _integralTerm The integral term
   */
  function getGainAdjustedPIOutput(int256 _proportionalTerm, int256 _integralTerm) external view returns (int256) {
    return _getGainAdjustedPIOutput(_proportionalTerm, _integralTerm);
  }

  function _getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) internal view virtual returns (int256 _adjsutedPIOutput) {
    (int256 _adjustedProportional, int256 _adjustedIntegral) = _getGainAdjustedTerms(_proportionalTerm, _integralTerm);
    return (_adjustedProportional + _adjustedIntegral);
  }

  function _getGainAdjustedTerms(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) internal view virtual returns (int256 _ajustedProportionalTerm, int256 _adjustedIntegralTerm) {
    return (_controllerGains.Kp.wmul(_proportionalTerm), _controllerGains.Ki.wmul(_integralTerm));
  }

  /**
   * @notice Independently return and calculate P * Kp and I * Ki
   * @param  _proportionalTerm The proportional term
   * @param  _integralTerm The integral term
   */
  function getGainAdjustedTerms(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view returns (int256 _ajustedProportionalTerm, int256 _adjustedIntegralTerm) {
    return _getGainAdjustedTerms(_proportionalTerm, _integralTerm);
  }

  /**
   * @notice Push new observations in deviationObservations & historicalCumulativeDeviations while also updating priceDeviationCumulative
   * @param  _proportionalTerm The proportionalTerm
   * @param  _accumulatedLeak The total leak (similar to a negative interest rate) applied to priceDeviationCumulative before proportionalTerm is added to it
   */
  function _updateDeviationHistory(int256 _proportionalTerm, uint256 _accumulatedLeak) internal virtual {
    (int256 _virtualDeviationCumulative,) = _getNextPriceDeviationCumulative(_proportionalTerm, _accumulatedLeak);
    priceDeviationCumulative = _virtualDeviationCumulative;
    historicalCumulativeDeviations.push(priceDeviationCumulative);
    deviationObservations.push(DeviationObservation(block.timestamp, _proportionalTerm, priceDeviationCumulative));
  }

  /**
   * @notice Compute a new priceDeviationCumulative (integral term)
   * @param  _proportionalTerm The proportional term (redemptionPrice - marketPrice)
   * @param  _accumulatedLeak The total leak applied to priceDeviationCumulative before it is summed with the new time adjusted deviation
   */
  function getNextPriceDeviationCumulative(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  ) external view returns (int256, int256) {
    return _getNextPriceDeviationCumulative(_proportionalTerm, _accumulatedLeak);
  }

  function _getNextPriceDeviationCumulative(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  ) internal view virtual returns (int256, int256) {
    int256 _lastProportionalTerm = _getLastProportionalTerm();
    uint256 _timeElapsed = _timeSinceLastUpdate();
    int256 _newTimeAdjustedDeviation =
      int256(_proportionalTerm).riemannSum(_lastProportionalTerm) * int256(_timeElapsed);
    int256 _leakedPriceCumulative = _accumulatedLeak.rmul(priceDeviationCumulative);

    return (_leakedPriceCumulative + _newTimeAdjustedDeviation, _newTimeAdjustedDeviation);
  }

  /**
   * @notice Compute and return the upcoming redemption rate
   * @param _marketPrice The system coin market price
   * @param _redemptionPrice The system coin redemption price
   * @param _accumulatedLeak The total leak applied to priceDeviationCumulative before it is summed with the proportionalTerm
   */
  function getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external view virtual returns (uint256 _redemptionRate, int256 _proportionalTerm, int256 _cumulativeDeviation) {
    return _getNextRedemptionRate(_marketPrice, _redemptionPrice, _accumulatedLeak);
  }

  function _getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) internal view virtual returns (uint256 _newRedemptionRate, int256 _proportionalTerm, int256 _cumulativeDeviation) {
    _proportionalTerm = _getProportionalTerm(_marketPrice, _redemptionPrice);
    (_cumulativeDeviation,) = _getNextPriceDeviationCumulative(_proportionalTerm, _accumulatedLeak);
    int256 _piOutput = _getGainAdjustedPIOutput(_proportionalTerm, _cumulativeDeviation);
    if (_breaksNoiseBarrier(Math.absolute(_piOutput), _redemptionPrice) && _piOutput != 0) {
      _newRedemptionRate = _getBoundedRedemptionRate(_piOutput);
      return (_newRedemptionRate, _proportionalTerm, _cumulativeDeviation);
    } else {
      return (RAY, _proportionalTerm, _cumulativeDeviation);
    }
  }

  /**
   * @notice Return the last proportional term stored in deviationObservations
   */
  function getLastProportionalTerm() external view returns (int256 _lastProportionalTerm) {
    return _getLastProportionalTerm();
  }

  function _getLastProportionalTerm() internal view virtual returns (int256 _lastProportionalTerm) {
    if (_oll() == 0) return 0;
    return deviationObservations[_oll() - 1].proportional;
  }

  /**
   * @notice Return the last integral term stored in deviationObservations
   */
  function getLastIntegralTerm() external view returns (int256 _lastIntegralTerm) {
    return _getLastIntegralTerm();
  }

  function _getLastIntegralTerm() internal view virtual returns (int256 _lastIntegralTerm) {
    if (_oll() == 0) return 0;
    return deviationObservations[_oll() - 1].integral;
  }

  /**
   * @notice Return the length of deviationObservations
   */
  function oll() external view returns (uint256 __oll) {
    return _oll();
  }

  function _oll() internal view virtual returns (uint256 __oll) {
    return deviationObservations.length;
  }

  /**
   * @notice Returns the time elapsed since the last computeRate call
   */
  function timeSinceLastUpdate() external view returns (uint256 _elapsed) {
    return _timeSinceLastUpdate();
  }

  function _timeSinceLastUpdate() internal view returns (uint256 _elapsed) {
    return lastUpdateTime == 0 ? 0 : block.timestamp - lastUpdateTime;
  }

  // --- Administration ---
  /**
   * @notice Modify an address parameter
   * @param  _parameter The name of the address parameter to change
   * @param  _addr The new address for the parameter
   */
  function modifyParameters(bytes32 _parameter, address _addr) external isAuthorized {
    if (_parameter == 'seedProposer') {
      seedProposer = _addr;
    } else {
      revert('PIDController/modify-unrecognized-param');
    }
  }

  /**
   * @notice Modify an uint256 parameter
   * @param  _parameter The name of the parameter to change
   * @param  _val The new value for the parameter
   */
  function modifyParameters(bytes32 _parameter, uint256 _val) external isAuthorized {
    if (_parameter == 'noiseBarrier') {
      require(_val > 0 && _val <= WAD, 'PIDController/invalid-noiseBarrier');
      noiseBarrier = _val;
    } else if (_parameter == 'integralPeriodSize') {
      require(_val > 0, 'PIDController/null-integralPeriodSize');
      integralPeriodSize = _val;
    } else if (_parameter == 'periodSize') {
      // NOTE: keeping both for backwards compatibility with periodSize
      require(_val > 0, 'PIDController/null-integralPeriodSize');
      integralPeriodSize = _val;
    } else if (_parameter == 'feedbackOutputUpperBound') {
      require(_val < _POSITIVE_RATE_LIMIT && _val > 0, 'PIDController/invalid-feedbackOutputUpperBound');
      feedbackOutputUpperBound = _val;
    } else if (_parameter == 'perSecondCumulativeLeak') {
      require(_val <= RAY, 'PIDController/invalid-perSecondCumulativeLeak');
      perSecondCumulativeLeak = _val;
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
    if (parameter == 'feedbackOutputLowerBound') {
      require(val < 0 && val >= -int256(_NEGATIVE_RATE_LIMIT), 'PIDController/invalid-feedbackOutputLowerBound');
      feedbackOutputLowerBound = val;
    } else if (parameter == 'kp') {
      require(val >= -int256(WAD) && val <= int256(WAD), 'PIDController/invalid-kp');
      _controllerGains.Kp = val;
    } else if (parameter == 'ki') {
      require(val >= -int256(WAD) && val <= int256(WAD), 'PIDController/invalid-ki');
      _controllerGains.Ki = val;
    } else if (parameter == 'priceDeviationCumulative') {
      require(_controllerGains.Ki == 0, 'PIDController/cannot-set-priceDeviationCumulative');
      priceDeviationCumulative = val;
    } else {
      revert('PIDController/modify-unrecognized-param');
    }
  }
}
