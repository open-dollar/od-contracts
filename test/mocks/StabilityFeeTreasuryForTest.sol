// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StabilityFeeTreasury, IStabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';

contract StabilityFeeTreasuryForTest is StabilityFeeTreasury {
  constructor(
    address _safeEngine,
    address _extraSurplusReceiver,
    address _coinJoin,
    StabilityFeeTreasuryParams memory _sfTreasuryParams
  ) StabilityFeeTreasury(_safeEngine, _extraSurplusReceiver, _coinJoin, _sfTreasuryParams) {}

  function joinAllCoins() external {
    _joinAllCoins();
  }
}
