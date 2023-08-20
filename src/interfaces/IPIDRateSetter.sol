// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IPIDController} from '@interfaces/IPIDController.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IPIDRateSetter is IAuthorizable, IModifiable {
  // --- Events ---
  event UpdateRedemptionRate(uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate);
  event FailUpdateRedemptionRate(
    uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate, bytes _reason
  );

  // --- Errors ---
  error PIDRateSetter_InvalidPriceFeed();
  error PIDRateSetter_RateSetterCooldown();

  // --- Structs ---
  struct PIDRateSetterParams {
    // Enforced gap between calls
    uint256 updateRateDelay; // [seconds]
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
  function params() external view returns (PIDRateSetterParams memory _pidRateSetterParams);
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
