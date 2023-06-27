// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';

import {CollateralJoinChild} from '@contracts/factories/CollateralJoinChild.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract CollateralJoinFactory is Authorizable, Disableable, ICollateralJoinFactory {
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using Assertions for address;

  // --- Registry ---
  address public safeEngine;

  // --- Data ---
  EnumerableSet.Bytes32Set internal _collateralTypes;
  mapping(bytes32 _cType => address _collateralJoin) public collateralJoins;

  // --- Init ---
  constructor(address _safeEngine) Authorizable(msg.sender) {
    safeEngine = _safeEngine.assertNonNull();
  }

  // --- Methods ---
  function deployCollateralJoin(
    bytes32 _cType,
    address _collateral
  ) external isAuthorized whenEnabled returns (address _collateralJoin) {
    if (!_collateralTypes.add(_cType)) revert CollateralJoinFactory_CollateralJoinExistent();

    _collateralJoin = address(new CollateralJoinChild(safeEngine, _cType, _collateral));
    collateralJoins[_cType] = _collateralJoin;
    IAuthorizable(safeEngine).addAuthorization(_collateralJoin);
    emit DeployCollateralJoin(_cType, _collateral, _collateralJoin);
  }

  function disableCollateralJoin(bytes32 _cType) external isAuthorized {
    if (!_collateralTypes.remove(_cType)) revert CollateralJoinFactory_CollateralJoinNonExistent();
    address _collateralJoin = collateralJoins[_cType];
    IDisableable(_collateralJoin).disableContract();
    delete collateralJoins[_cType];
    // NOTE: doesn't revoke authorization from safeEngine (cJoin can still exit collateral)
    emit DisableCollateralJoin(_collateralJoin);
  }

  // --- Views ---
  function collateralTypesList() external view returns (bytes32[] memory _collateralTypesList) {
    return _collateralTypes.values();
  }

  function collateralJoinsList() external view returns (address[] memory _collateralJoinsList) {
    bytes32[] memory _collateralTypesList = _collateralTypes.values();
    _collateralJoinsList = new address[](_collateralTypesList.length);
    for (uint256 i; i < _collateralTypesList.length; i++) {
      _collateralJoinsList[i] = collateralJoins[_collateralTypesList[i]];
    }
  }
}
