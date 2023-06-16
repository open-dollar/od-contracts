// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  CollateralJoinFactory, ICollateralJoinFactory, EnumerableSet
} from '@contracts/utils/CollateralJoinFactory.sol';

contract CollateralJoinFactoryForTest is CollateralJoinFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(address _safeEngine) CollateralJoinFactory(_safeEngine) {}

  function addCollateralJoin(address _collateralJoin) external {
    _collateralJoins.add(_collateralJoin);
  }
}
