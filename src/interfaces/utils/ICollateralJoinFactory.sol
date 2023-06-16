// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ICollateralJoinFactory is IAuthorizable, IDisableable {
  // --- Events ---
  event DeployCollateralJoin(bytes32 indexed _cType, address indexed _collateral, address indexed _collateralJoin);
  event DisableCollateralJoin(address indexed _collateralJoin);

  // --- Errors ---
  error CollateralJoinFactory_NotCollateralJoin();

  // --- Methods ---
  function deployCollateralJoin(bytes32 _cType, address _collateral) external returns (address _collateralJoin);
  function disableCollateralJoin(address _collateralJoin) external;

  // --- Views ---
  function safeEngine() external view returns (address _safeEngine);
  function collateralJoinsList() external view returns (address[] memory _collateralJoinsList);
}
