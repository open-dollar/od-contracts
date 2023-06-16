// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralJoinFactory} from '@interfaces/utils/ICollateralJoinFactory.sol';

import {CollateralJoin, ICollateralJoin} from '@contracts/utils/CollateralJoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract CollateralJoinFactory is Authorizable, Disableable, ICollateralJoinFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Registry ---
  address public safeEngine;

  // --- Data ---
  EnumerableSet.AddressSet internal _collateralJoins;

  // --- Init ---
  constructor(address _safeEngine) Authorizable(msg.sender) {
    safeEngine = _safeEngine;
  }

  // --- Methods ---
  function deployCollateralJoin(
    bytes32 _cType,
    address _collateral
  ) external isAuthorized whenEnabled returns (address _collateralJoin) {
    _collateralJoin = address(new CollateralJoin(safeEngine, _cType, _collateral));
    _collateralJoins.add(_collateralJoin);
    emit DeployCollateralJoin(_cType, _collateral, _collateralJoin);
  }

  function disableCollateralJoin(address _collateralJoin) external isAuthorized {
    if (!_collateralJoins.remove(_collateralJoin)) revert CollateralJoinFactory_NotCollateralJoin();
    ICollateralJoin(_collateralJoin).disableContract();
    emit DisableCollateralJoin(_collateralJoin);
  }

  // --- Views ---
  function collateralJoinsList() external view returns (address[] memory _collateralJoinsList) {
    return _collateralJoins.values();
  }
}
