// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

interface IPIDRateSetter is IAuthorizable {
  // --- Events ---
  event ModifyParameters(bytes32 _parameter, address _addr);
  event ModifyParameters(bytes32 _parameter, uint256 _val);
  event UpdateRedemptionRate(uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate);
  event FailUpdateRedemptionRate(
    uint256 _marketPrice, uint256 _redemptionPrice, uint256 _redemptionRate, bytes _reason
  );

  function lastUpdateTime() external view returns (uint256 _lastUpdateTime);
  function updateRateDelay() external view returns (uint256 _updateRateDelay);
  function defaultLeak() external view returns (uint256 _defaultLeak);
  function orcl() external view returns (IOracle _orcl);
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);
  function pidCalculator() external view returns (IPIDController _pidCalculator);
  function getMarketPrice() external view returns (uint256 _marketPrice);

  function getRedemptionAndMarketPrices() external returns (uint256 _redemptionPrice, uint256 _marketPrice);
  function updateRate() external;
}
