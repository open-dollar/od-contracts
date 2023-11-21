// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
  CollateralJoinFactory, ICollateralJoinFactory, EnumerableSet
} from '@contracts/factories/CollateralJoinFactory.sol';

contract CollateralJoinFactoryForTest is CollateralJoinFactory {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(address _safeEngine) CollateralJoinFactory(_safeEngine) {}

  function addCollateralJoin(bytes32 _cType, address _collateralJoin) external {
    _collateralTypes.add(_cType);
    collateralJoins[_cType] = _collateralJoin;
  }

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }
}
