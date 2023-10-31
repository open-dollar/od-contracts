// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IPIDController} from '@interfaces/IPIDController.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IPIDRateSetter is IAuthorizable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when the redemption rate is updated
   * @param _marketPrice Computed price of the system coin
   * @param _redemptionPrice Redemption price of the system coin
   * @param _redemptionRate Resulting new redemption rate
   */
  event UpdateRedemptionRate(uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate);

  // --- Errors ---

  /// @notice Throws if the market price feed returns an invalid value
  error PIDRateSetter_InvalidPriceFeed();
  /// @notice Throws if the call to `updateRate` is too soon since last update
  error PIDRateSetter_RateSetterCooldown();

  // --- Structs ---

  struct PIDRateSetterParams {
    // Enforced gap between calls
    uint256 /* seconds */ updateRateDelay;
  }

  // --- Registry ---

  /**
   * @notice The oracle relayer where the redemption price and rate are stored
   */
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);

  /**
   * @notice The PID calculator used to compute the redemption rate
   */
  function pidCalculator() external view returns (IPIDController _pidCalculator);

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _pidRateSetterParams PIDRateSetter parameters struct
   */
  function params() external view returns (PIDRateSetterParams memory _pidRateSetterParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _updateRateDelay Enforced gap between calls
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _updateRateDelay);

  // --- Data ---

  /**
   * @notice The timestamp of the last update
   */
  function lastUpdateTime() external view returns (uint256 _lastUpdateTime);

  // --- Methods ---

  /**
   * @notice Compute and set a new redemption rate
   */
  function updateRate() external;
}
