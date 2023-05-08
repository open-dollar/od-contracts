// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOracle as OracleLike} from '@interfaces/IOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface IOracleRelayer is IAuthorizable, IDisableable {
  // --- Events ---
  event ModifyParameters(bytes32 _collateralType, bytes32 _parameter, address _addr);
  event ModifyParameters(bytes32 _parameter, uint256 _data);
  event ModifyParameters(bytes32 _collateralType, bytes32 _parameter, uint256 _data);
  event UpdateRedemptionPrice(uint256 _redemptionPrice);
  event UpdateCollateralPrice(
    bytes32 indexed _collateralType, uint256 _priceFeedValue, uint256 _safetyPrice, uint256 _liquidationPrice
  );

  // --- Data ---
  struct CollateralType {
    // Usually an oracle security module that enforces delays to fresh price feeds
    OracleLike orcl;
    // CRatio used to compute the 'safePrice' - the price used when generating debt in SAFEEngine
    uint256 safetyCRatio;
    // CRatio used to compute the 'liquidationPrice' - the price used when liquidating SAFEs
    uint256 liquidationCRatio;
  }

  function redemptionPrice() external returns (uint256 _redemptionPrice);
  function collateralTypes(bytes32)
    external
    view
    returns (OracleLike _oracle, uint256 _safetyCRatio, uint256 _liquidationCRatio);
  function updateCollateralPrice(bytes32 _collateralType) external;
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function redemptionRate() external view returns (uint256 _redemptionRate);
  function redemptionPriceUpdateTime() external view returns (uint256 _redemptionPriceUpdateTime);
  function redemptionRateUpperBound() external view returns (uint256 _redemptionRateUpperBound);
  function redemptionRateLowerBound() external view returns (uint256 _redemptionRateLowerBound);
  function safetyCRatio(bytes32 _collateralType) external view returns (uint256 _safetyCRatio);
  function liquidationCRatio(bytes32 _collateralType) external view returns (uint256 _liquidationCRatio);
  function orcl(bytes32 _collateralType) external view returns (address _oracle);
}
