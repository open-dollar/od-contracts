// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

import {CollateralJoinChild} from '@contracts/factories/CollateralJoinChild.sol';
import {CollateralJoinDelegatableChild} from '@contracts/factories/CollateralJoinDelegatableChild.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  CollateralJoinFactory
 * @notice This contract is used to deploy CollateralJoin contracts
 * @dev    The deployed contracts are CollateralJoinChild or CollateralJoinDelegatableChild instances
 */
contract CollateralJoinFactory is Authorizable, Disableable, ICollateralJoinFactory {
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc ICollateralJoinFactory
  address public safeEngine;

  // --- Data ---

  /// @notice The enumerable set of deployed CollateralJoin contracts
  EnumerableSet.Bytes32Set internal _collateralTypes;

  /// @inheritdoc ICollateralJoinFactory
  mapping(bytes32 _cType => address _collateralJoin) public collateralJoins;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   */
  constructor(address _safeEngine) Authorizable(msg.sender) {
    safeEngine = _safeEngine.assertNonNull();
  }

  // --- Methods ---

  /// @inheritdoc ICollateralJoinFactory
  function deployCollateralJoin(
    bytes32 _cType,
    address _collateral
  ) external isAuthorized whenEnabled returns (ICollateralJoin _collateralJoin) {
    if (!_collateralTypes.add(_cType)) revert CollateralJoinFactory_CollateralJoinExistent();

    _collateralJoin = new CollateralJoinChild(safeEngine, _cType, _collateral);
    collateralJoins[_cType] = address(_collateralJoin);
    IAuthorizable(safeEngine).addAuthorization(address(_collateralJoin));
    emit DeployCollateralJoin(_cType, _collateral, address(_collateralJoin));
  }

  /// @inheritdoc ICollateralJoinFactory
  function deployDelegatableCollateralJoin(
    bytes32 _cType,
    address _collateral,
    address _delegatee
  ) external isAuthorized whenEnabled returns (ICollateralJoin _collateralJoin) {
    if (!_collateralTypes.add(_cType)) revert CollateralJoinFactory_CollateralJoinExistent();

    _collateralJoin = new CollateralJoinDelegatableChild(safeEngine, _cType, _collateral, _delegatee);
    collateralJoins[_cType] = address(_collateralJoin);
    IAuthorizable(safeEngine).addAuthorization(address(_collateralJoin));
    emit DeployCollateralJoin(_cType, _collateral, address(_collateralJoin));
  }

  /// @inheritdoc ICollateralJoinFactory
  function disableCollateralJoin(bytes32 _cType) external isAuthorized {
    if (!_collateralTypes.remove(_cType)) revert CollateralJoinFactory_CollateralJoinNonExistent();
    address _collateralJoin = collateralJoins[_cType];
    IDisableable(_collateralJoin).disableContract();
    delete collateralJoins[_cType];
    // NOTE: doesn't revoke authorization from safeEngine (cJoin can still exit collateral)
    emit DisableCollateralJoin(_collateralJoin);
  }

  // --- Views ---

  /// @inheritdoc ICollateralJoinFactory
  function collateralTypesList() external view returns (bytes32[] memory _collateralTypesList) {
    return _collateralTypes.values();
  }

  /// @inheritdoc ICollateralJoinFactory
  function collateralJoinsList() external view returns (address[] memory _collateralJoinsList) {
    bytes32[] memory _collateralTypesList = _collateralTypes.values();
    _collateralJoinsList = new address[](_collateralTypesList.length);
    for (uint256 _i; _i < _collateralTypesList.length; ++_i) {
      _collateralJoinsList[_i] = collateralJoins[_collateralTypesList[_i]];
    }
  }
}
