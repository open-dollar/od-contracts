// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IPIDController} from '@interfaces/IPIDController.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface IPIDRateSetter is IAuthorizable, IModifiable {
  // --- Errors ---
  error InvalidPriceFeed();
  error RateSetterCooldown();

  // --- Events ---
  event UpdateRedemptionRate(uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate);
  event FailUpdateRedemptionRate(
    uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate, bytes _reason
  );

  // --- Structs ---
  struct PIDRateSetterParams {
    // Enforced gap between calls
    uint256 updateRateDelay; // [seconds]
  }

  // --- Registry ---
  /**
   * @notice The oracle used to fetch the system coin market price
   */
  function oracle() external view returns (IBaseOracle _oracle);

  /**
   * @notice The oracle relayer where the redemption price and rate are stored
   */
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);

  /**
   * @notice The PID calculator used to compute the redemption rate
   */
  function pidCalculator() external view returns (IPIDController _pidCalculator);

  // --- Params ---
  function params() external view returns (PIDRateSetterParams memory);

  // --- Data ---
  /**
   * @notice The timestamp of the last update
   */
  function lastUpdateTime() external view returns (uint256 _lastUpdateTime);

  /**
   * @notice Get the market price from the system coin oracle
   */
  function getMarketPrice() external view returns (uint256 _marketPrice);

  // --- Methods ---
  /**
   * @notice Get (and update) the redemption price and the market price for the system coin
   * @return _redemptionPrice
   * @return _marketPrice
   */
  function getRedemptionAndMarketPrices() external returns (uint256 _redemptionPrice, uint256 _marketPrice);

  /**
   * @notice Compute and set a new redemption rate
   */
  function updateRate() external;
}
