// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IPIDController} from '@interfaces/IPIDController.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface IPIDRateSetter is IAuthorizable, IModifiable {
  // --- Events ---
  event UpdateRedemptionRate(uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate);
  event FailUpdateRedemptionRate(
    uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate, bytes _reason
  );

  // --- Structs ---
  struct PIDRateSetterParams {
    // Enforced gap between calls
    uint256 updateRateDelay; // [seconds]
    // Whether the leak is set to zero by default
    uint256 defaultLeak; // [0 or 1]
  }

  // --- Registry ---
  function oracle() external view returns (IOracle _oracle);
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);
  function pidCalculator() external view returns (IPIDController _pidCalculator);

  // --- Params ---
  function params() external view returns (PIDRateSetterParams memory);

  // --- Data ---
  function lastUpdateTime() external view returns (uint256 _lastUpdateTime);
  function getMarketPrice() external view returns (uint256 _marketPrice);

  // --- Methods ---
  function getRedemptionAndMarketPrices() external returns (uint256 _redemptionPrice, uint256 _marketPrice);
  function updateRate() external;
}
