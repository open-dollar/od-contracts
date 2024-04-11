// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IPIDController is IAuthorizable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when the state of the controller is updated
   * @param _proportionalDeviation The new proportional term
   * @param _integralDeviation The new integral term
   * @param _deltaIntegralDeviation The delta between the new and the previous integral term
   */
  event UpdateDeviation(int256 _proportionalDeviation, int256 _integralDeviation, int256 _deltaIntegralDeviation);

  // --- Errors ---

  /// @notice Throws if the caller of `updateRate` is not the seed proposer
  error PIDController_OnlySeedProposer();
  /// @notice Throws if the call to `updateRate` is too soon since last update
  error PIDController_ComputeRateCooldown();
  /// @notice Throws when trying to set the integral term with the integral gain set on
  error PIDController_CannotSetPriceDeviationCumulative();

  // --- Structs ---

  struct PIDControllerParams {
    // The minimum delay between two computeRate calls
    uint256 /* seconds */ integralPeriodSize;
    // The per second leak applied to priceDeviationCumulative before the latest deviation is added
    uint256 /* RAY     */ perSecondCumulativeLeak;
    // The minimum percentage deviation from the redemption price that allows the contract to calculate a non null redemption rate
    uint256 /* WAD     */ noiseBarrier;
    // The maximum value allowed for the redemption rate
    uint256 /* RAY     */ feedbackOutputUpperBound;
    // The minimum value allowed for the redemption rate
    int256 /*  RAY     */ feedbackOutputLowerBound;
  }

  struct DeviationObservation {
    // The timestamp when this observation was stored
    uint256 timestamp;
    // The proportional term stored in this observation
    int256 proportional;
    // The integral term stored in this observation
    int256 integral;
  }

  struct ControllerGains {
    // This value is multiplied with the proportional term
    int256 /* WAD */ kp;
    // This value is multiplied with priceDeviationCumulative
    int256 /* WAD */ ki;
  }

  // --- Registry ---

  /**
   * @notice Returns the address allowed to call computeRate method
   */
  function seedProposer() external view returns (address _seedProposer);

  // --- Data ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _pidParams The PID controller parameters struct
   */
  function params() external view returns (PIDControllerParams memory _pidParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _integralPeriodSize The minimum delay between two computeRate calls
   * @return _perSecondCumulativeLeak The per second leak applied to priceDeviationCumulative before the latest deviation is added [ray]
   * @return _noiseBarrier The minimum percentage deviation from the redemption price that allows the contract to calculate a non null redemption rate [wad]
   * @return _feedbackOutputUpperBound The maximum value allowed for the redemption rate [ray]
   * @return _feedbackOutputLowerBound The minimum value allowed for the redemption rate [ray]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (
      uint256 _integralPeriodSize,
      uint256 _perSecondCumulativeLeak,
      uint256 _noiseBarrier,
      uint256 _feedbackOutputUpperBound,
      int256 _feedbackOutputLowerBound
    );

  /**
   * @notice Returns the last deviation observation, containing latest timestamp, proportional and integral terms
   * @return __deviationObservation The last deviation observation struct
   */
  function deviationObservation() external view returns (DeviationObservation memory __deviationObservation);

  /**
   * @notice Raw data about the last deviation observation
   * @return _timestamp The timestamp when this observation was stored
   * @return _proportional The proportional term stored in this observation
   * @return _integral The integral term stored in this observation
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _deviationObservation() external view returns (uint256 _timestamp, int256 _proportional, int256 _integral);

  /**
   * @notice Returns the Kp and Ki values used in this calculator
   * @dev    The values are expressed in WAD, Kp stands for proportional and Ki for integral terms
   */
  function controllerGains() external view returns (ControllerGains memory _cGains);

  /**
   * @notice Raw data about the Kp and Ki values used in this calculator
   * @return _kp This value is multiplied with the proportional term
   * @return _ki This value is multiplied with priceDeviationCumulative
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _controllerGains() external view returns (int256 _kp, int256 _ki);

  /**
   * @notice Return a redemption rate bounded by feedbackOutputLowerBound and feedbackOutputUpperBound as well as the
   *         timeline over which that rate will take effect
   * @param  _piOutput The raw redemption rate computed from the proportional and integral terms
   * @return _redemptionRate The bounded redemption rate
   */
  function getBoundedRedemptionRate(int256 _piOutput) external view returns (uint256 _redemptionRate);

  /**
   * @notice Compute a new redemption rate
   * @param  _marketPrice The system coin market price
   * @param  _redemptionPrice The system coin redemption price
   * @return _redemptionRate The computed redemption rate
   */
  function computeRate(uint256 _marketPrice, uint256 _redemptionPrice) external returns (uint256 _redemptionRate);

  /**
   * @notice Apply Kp to the proportional term and Ki to the integral term (by multiplication) and then sum P and I
   * @param  _proportionalTerm The proportional term
   * @param  _integralTerm The integral term
   * @return _piOutput The sum of P and I
   */
  function getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view returns (int256 _piOutput);

  /**
   * @notice Independently return and calculate P * Kp and I * Ki
   * @param  _proportionalTerm The proportional term
   * @param  _integralTerm The integral term
   * @return _proportionalGain The proportional gain
   * @return _integralGain The integral gain
   */
  function getGainAdjustedTerms(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view returns (int256 _proportionalGain, int256 _integralGain);

  /**
   * @notice Compute a new priceDeviationCumulative (integral term)
   * @param  _proportionalTerm The proportional term (redemptionPrice - marketPrice)
   * @param  _accumulatedLeak The total leak applied to priceDeviationCumulative before it is summed with the new time adjusted deviation
   * @return _priceDeviationCumulative The new priceDeviationCumulative
   * @return _timeAdjustedDeviation The new time adjusted deviation
   */
  function getNextDeviationCumulative(
    int256 _proportionalTerm,
    uint256 _accumulatedLeak
  ) external returns (int256 _priceDeviationCumulative, int256 _timeAdjustedDeviation);

  /**
   * @notice Returns whether the P + I sum exceeds the noise barrier
   * @param  _piSum Represents a sum between P + I
   * @param  _redemptionPrice The system coin redemption price
   * @return _breaksNb Whether the P + I sum exceeds the noise barrier
   */
  function breaksNoiseBarrier(uint256 _piSum, uint256 _redemptionPrice) external view returns (bool _breaksNb);

  /**
   * @notice Compute and return the upcoming redemption rate
   * @param _marketPrice The system coin market price
   * @param _redemptionPrice The system coin redemption price
   * @param _accumulatedLeak The total leak applied to priceDeviationCumulative before it is summed with the proportionalTerm
   * @return _redemptionRate The upcoming redemption rate
   * @return _proportionalTerm The upcoming proportional term
   * @return _integralTerm The upcoming integral term
   */
  function getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external view returns (uint256 _redemptionRate, int256 _proportionalTerm, int256 _integralTerm);

  /**
   * @notice Returns the time elapsed since the last computeRate call
   */
  function timeSinceLastUpdate() external view returns (uint256 _timeSinceLastValue);
}
