// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ICollateralJoinFactory is IAuthorizable, IDisableable {
  // --- Events ---
  event DeployCollateralJoin(bytes32 indexed _cType, address indexed _collateral, address indexed _collateralJoin);
  event DisableCollateralJoin(address indexed _collateralJoin);

  // --- Errors ---
  error CollateralJoinFactory_CollateralJoinExistent();
  error CollateralJoinFactory_CollateralJoinNonExistent();

  // --- Registry ---
  function safeEngine() external view returns (address _safeEngine);

  // --- Data ---
  function collateralTypesList() external view returns (bytes32[] memory _collateralTypesList);
  function collateralJoinsList() external view returns (address[] memory _collateralJoinsList);

  // --- Methods ---
  function deployCollateralJoin(bytes32 _cType, address _collateral) external returns (address _collateralJoin);
  function deployDelegatableCollateralJoin(
    bytes32 _cType,
    address _collateral,
    address _delegatee
  ) external returns (address _collateralJoin);
  function disableCollateralJoin(bytes32 _cType) external;
}
