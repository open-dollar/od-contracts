// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {CollateralJoin, ICollateralJoin} from '@contracts/utils/CollateralJoin.sol';

contract CollateralJoinForTest is CollateralJoin {
  constructor(
    address _safeEngine,
    bytes32 _cType,
    address _collateral
  ) CollateralJoin(_safeEngine, _cType, _collateral) {}

  function whenFactoryEnabledModifier() external whenFactoryEnabled {}
}
