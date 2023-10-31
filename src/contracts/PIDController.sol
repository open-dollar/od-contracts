// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IPIDController} from '@interfaces/IPIDController.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Math, WAD, RAY} from '@libraries/Math.sol';

/**
 * @title  PIDController
 * @notice Redemption Rate Feedback Mechanism (RRFM) controller that implements a PI controller
 */
contract PIDController is Authorizable, Modifiable, IPIDController {
  using Math for uint256;
  using Math for int256;
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for int256;
  using Assertions for address;

  /**
   * @notice The lower (when negative) bound for the redemption rate
   * @dev    Represents a rate of -99.999% per second (as -100% is not allowed) in RAY precision
   */
  uint256 internal constant _NEGATIVE_RATE_LIMIT = RAY - 1;

  /**
   * @notice The upper bound for the redemption rate
   * @dev    Maximum possible value that can be safely casted to int256
   */
  uint256 internal constant _POSITIVE_RATE_LIMIT = uint256(type(int256).max);

  // --- Registry ---

  /// @inheritdoc IPIDController
  address public seedProposer;

  // --- Data ---

  /// @inheritdoc IPIDController
  // solhint-disable-next-line private-vars-leading-underscore
  PIDControllerParams public _params;

  /// @inheritdoc IPIDController
  function params() external view returns (PIDControllerParams memory _pidParams) {
    return _params;
  }

  /// @inheritdoc IPIDController
  /// @dev The last deviation observation, containing latest timestamp, proportional and integral terms
  // solhint-disable-next-line private-vars-leading-underscore
  DeviationObservation public _deviationObservation;

  /// @inheritdoc IPIDController
  function deviationObservation() external view returns (DeviationObservation memory __deviationObservation) {
    return _deviationObservation;
  }

  // -- Static & Default Variables ---

  /// @inheritdoc IPIDController
  // solhint-disable-next-line private-vars-leading-underscore
  ControllerGains public _controllerGains;

  /// @inheritdoc IPIDController
  function controllerGains() external view returns (ControllerGains memory _cGains) {
    return _controllerGains;
  }

  /**
   * @param  _cGains Initial valid controller gains settings struct
   * @param  _pidParams Initial valid PID controller parameters struct
   * @param  _importedState Imported initial state of the controller (optional)
   */
  constructor(
    ControllerGains memory _cGains,
    PIDControllerParams memory _pidParams,
    DeviationObservation memory _importedState
  ) Authorizable(msg.sender) validParams {
    _params = _pidParams;
    _controllerGains = _cGains;

    if (_importedState.timestamp > 0) {
      _deviationObservation = DeviationObservation({
        timestamp: _importedState.timestamp.assertLtEq(block.timestamp),
        proportional: _importedState.proportional,
        integral: _importedState.integral
      });
    }
  }

  /// @inheritdoc IPIDController
  function getBoundedRedemptionRate(int256 _piOutput) external view returns (uint256 _newRedemptionRate) {
    return _getBoundedRedemptionRate(_piOutput);
  }

  /// @dev Computes the new redemption rate by taking into account the feedbackOutputUpperBound and feedbackOutputLowerBound
  function _getBoundedRedemptionRate(int256 _piOutput) internal view virtual returns (uint256 _newRedemptionRate) {
    int256 _boundedPIOutput = _getBoundedPIOutput(_piOutput);

    // feedbackOutputLowerBound will never be less than NEGATIVE_RATE_LIMIT : RAY - 1,
    // and feedbackOutputUpperBound will never be greater than POSITIVE_RATE_LIMIT : uint256(type(int256).max)
    // boundedPIOutput can be safely added to RAY
    _newRedemptionRate = _boundedPIOutput < -int256(RAY) ? _NEGATIVE_RATE_LIMIT : RAY.add(_boundedPIOutput);

    return _newRedemptionRate;
  }

  /// @dev Computes the pi output by taking into account the feedbackOutputUpperBound and feedbackOutputLowerBound
  function _getBoundedPIOutput(int256 _piOutput) internal view virtual returns (int256 _boundedPIOutput) {
    _boundedPIOutput = _piOutput;
    if (_piOutput < _params.feedbackOutputLowerBound) {
      _boundedPIOutput = _params.feedbackOutputLowerBound;
    } else if (_piOutput > _params.feedbackOutputUpperBound.toInt()) {
      _boundedPIOutput = int256(_params.feedbackOutputUpperBound);
    }
    return _boundedPIOutput;
  }

  // --- Rate Validation/Calculation ---

  /// @inheritdoc IPIDController
  function computeRate(uint256 _marketPrice, uint256 _redemptionPrice) external returns (uint256 _newRedemptionRate) {
    if (msg.sender != seedProposer) revert PIDController_OnlySeedProposer();
    uint256 __timeSinceLastUpdate = _timeSinceLastUpdate();
    // Ensure that at least integralPeriodSize seconds passed since the last update or that this is the first update
    if (__timeSinceLastUpdate < _params.integralPeriodSize && _deviationObservation.timestamp != 0) {
      revert PIDController_ComputeRateCooldown();
    }
    int256 _proportionalTerm = _getProportionalTerm(_marketPrice, _redemptionPrice);
    // Update the integral term by passing the proportional (current deviation) and the total leak that will be applied to the integral
    uint256 _accumulatedLeak = _params.perSecondCumulativeLeak.rpow(__timeSinceLastUpdate);
    int256 _integralTerm = _updateDeviation(_proportionalTerm, _accumulatedLeak);
    // Multiply P by Kp and I by Ki and then sum P & I in order to return the result
    int256 _piOutput = _getGainAdjustedPIOutput(_proportionalTerm, _integralTerm);
    // If the P * Kp + I * Ki output breaks the noise barrier, you can recompute a non null rate
    if (_breaksNoiseBarrier(Math.absolute(_piOutput), _redemptionPrice)) {
      // Get the new redemption rate by taking into account the feedbackOutputUpperBound and feedbackOutputLowerBound
      return _getBoundedRedemptionRate(_piOutput);
    } else {
      // If controller output is below noise barrier, return RAY
      return RAY;
    }
  }

  /// @dev Computes the proportional term using the scaled difference between market price and redemption price
  function _getProportionalTerm(
    uint256 _marketPrice,
    uint256 _redemptionPrice
  ) internal view virtual returns (int256 _proportionalTerm) {
    // Scale the market price by 10^9 so it also has 27 decimals like the redemption price
    uint256 _scaledMarketPrice = _marketPrice * 1e9;

    // Calculate the proportional term as (redemptionPrice - marketPrice) * RAY / redemptionPrice
    _proportionalTerm = _redemptionPrice.sub(_scaledMarketPrice).rdiv(int256(_redemptionPrice)); // safe cast: cannot overflow because minuend of sub

    return _proportionalTerm;
  }

  /// @inheritdoc IPIDController
  function breaksNoiseBarrier(uint256 _piSum, uint256 _redemptionPrice) external view virtual returns (bool _breaksNb) {
    return _breaksNoiseBarrier(_piSum, _redemptionPrice);
  }

  /// @dev Returns whether the P + I sum exceeds the noise barrier
  function _breaksNoiseBarrier(uint256 _piSum, uint256 _redemptionPrice) internal view virtual returns (bool _breaksNb) {
    if (_piSum == 0) return false;
    uint256 _deltaNoise = 2 * WAD - _params.noiseBarrier;
    return _piSum >= _redemptionPrice.wmul(_deltaNoise) - _redemptionPrice;
  }

  /// @inheritdoc IPIDController
  function getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view returns (int256 _gainAdjustedPIOutput) {
    return _getGainAdjustedPIOutput(_proportionalTerm, _integralTerm);
  }

  /// @dev Computes the gain adjusted PI output by multiplying P by Kp and I by Ki and then sum P & I
  function _getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) internal view virtual returns (int256 _adjustedPIOutput) {
    (int256 _adjustedProportional, int256 _adjustedIntegral) = _getGainAdjustedTerms(_proportionalTerm, _integralTerm);
    return (_adjustedProportional + _adjustedIntegral);
  }

  /// @dev Computes the gain adjusted terms by multiplying P by Kp and I by Ki
  function _getGainAdjustedTerms(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) internal view virtual returns (int256 _ajustedProportionalTerm, int256 _adjustedIntegralTerm) {
    return (_controllerGains.kp.wmul(_proportionalTerm), _controllerGains.ki.wmul(_integralTerm));
  }

  /// @inheritdoc IPIDController
  function getGainAdjustedTerms(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view returns (int256 _ajustedProportionalTerm, int256 _adjustedIntegralTerm) {
    return _getGainAdjustedTerms(_proportionalTerm, _integralTerm);
  }

  /**
   * @notice Push new observations in deviationObservations while also updating priceDeviationCumulative
   * @param  _proportionalTerm The proportionalTerm
   * @param  _accumulatedLeak The total leak (similar to a negative interest rate) applied to priceDeviationCumulative before proportionalTerm is added to it
   */
  function _updateDeviation(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  ) internal virtual returns (int256 _integralTerm) {
    int256 _appliedDeviation;
    (_integralTerm, _appliedDeviation) = _getNextDeviationCumulative(_proportionalTerm, _accumulatedLeak);
    // Update the last deviation observation
    _deviationObservation = DeviationObservation(block.timestamp, _proportionalTerm, _integralTerm);
    // Emit event to track the deviation history and the applied leak
    emit UpdateDeviation(_proportionalTerm, _integralTerm, _appliedDeviation);
  }

  /// @inheritdoc IPIDController
  function getNextDeviationCumulative(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  ) external view returns (int256 _nextDeviationCumulative, int256 _appliedDeviation) {
    return _getNextDeviationCumulative(_proportionalTerm, _accumulatedLeak);
  }

  /// @dev Computes the new priceDeviationCumulative (integral term)
  function _getNextDeviationCumulative(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  ) internal view virtual returns (int256 _nextDeviationCumulative, int256 _appliedDeviation) {
    int256 _lastProportionalTerm = _deviationObservation.proportional;
    uint256 _timeElapsed = _timeSinceLastUpdate();
    int256 _newTimeAdjustedDeviation = _proportionalTerm.riemannSum(_lastProportionalTerm) * int256(_timeElapsed);
    int256 _leakedPriceCumulative = _accumulatedLeak.rmul(_deviationObservation.integral);

    return (_leakedPriceCumulative + _newTimeAdjustedDeviation, _newTimeAdjustedDeviation);
  }

  /**
   * @dev    This method is used to provide a view of the next redemption rate without updating the state of the controller
   * @inheritdoc IPIDController
   */
  function getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external view returns (uint256 _redemptionRate, int256 _proportionalTerm, int256 _integralTerm) {
    _proportionalTerm = _getProportionalTerm(_marketPrice, _redemptionPrice);
    (_integralTerm,) = _getNextDeviationCumulative(_proportionalTerm, _accumulatedLeak);
    int256 _piOutput = _getGainAdjustedPIOutput(_proportionalTerm, _integralTerm);
    if (_breaksNoiseBarrier(Math.absolute(_piOutput), _redemptionPrice)) {
      _redemptionRate = _getBoundedRedemptionRate(_piOutput);
      return (_redemptionRate, _proportionalTerm, _integralTerm);
    } else {
      return (RAY, _proportionalTerm, _integralTerm);
    }
  }

  /// @inheritdoc IPIDController
  function timeSinceLastUpdate() external view returns (uint256 _elapsed) {
    return _timeSinceLastUpdate();
  }

  function _timeSinceLastUpdate() internal view returns (uint256 _elapsed) {
    return _deviationObservation.timestamp == 0 ? 0 : block.timestamp - _deviationObservation.timestamp;
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();
    int256 _int256 = _data.toInt256();

    if (_param == 'seedProposer') {
      seedProposer = _data.toAddress().assertNonNull();
    } else if (_param == 'noiseBarrier') {
      _params.noiseBarrier = _uint256;
    } else if (_param == 'integralPeriodSize') {
      _params.integralPeriodSize = _uint256;
    } else if (_param == 'feedbackOutputUpperBound') {
      _params.feedbackOutputUpperBound = _uint256;
    } else if (_param == 'feedbackOutputLowerBound') {
      _params.feedbackOutputLowerBound = _int256;
    } else if (_param == 'perSecondCumulativeLeak') {
      _params.perSecondCumulativeLeak = _uint256;
    } else if (_param == 'kp') {
      _controllerGains.kp = _int256;
    } else if (_param == 'ki') {
      _controllerGains.ki = _int256;
    } else if (_param == 'priceDeviationCumulative') {
      // Allows governance to set a starting value for the integral term (only when the integral gain is off)
      if (_controllerGains.ki != 0) revert PIDController_CannotSetPriceDeviationCumulative();
      _deviationObservation.integral = _int256;
    } else {
      revert UnrecognizedParam();
    }
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    _params.integralPeriodSize.assertNonNull();
    _params.noiseBarrier.assertNonNull().assertLtEq(WAD);
    _params.feedbackOutputUpperBound.assertNonNull().assertLtEq(_POSITIVE_RATE_LIMIT);
    _params.feedbackOutputLowerBound.assertLt(0).assertGtEq(-int256(_NEGATIVE_RATE_LIMIT));
    _params.perSecondCumulativeLeak.assertLtEq(RAY);

    _controllerGains.kp.assertGtEq(-int256(WAD)).assertLtEq(int256(WAD));
    _controllerGains.ki.assertGtEq(-int256(WAD)).assertLtEq(int256(WAD));
  }
}
