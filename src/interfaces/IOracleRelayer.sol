// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOracle as OracleLike} from './IOracle.sol';
import {IDisableable} from './IDisableable.sol';
import {IAuthorizable} from './IAuthorizable.sol';

interface IOracleRelayer is IDisableable, IAuthorizable {
  function redemptionPrice() external returns (uint256 _redemptionPrice);
  function collateralTypes(bytes32)
    external
    view
    returns (OracleLike _oracle, uint256 _safetyCRatio, uint256 _liquidationCRatio);
  function updateCollateralPrice(bytes32 _collateralType) external;
}
