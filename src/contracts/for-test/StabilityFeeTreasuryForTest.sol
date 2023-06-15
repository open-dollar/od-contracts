// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IStabilityFeeTreasury, StabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {Math} from '@libraries/Math.sol';

contract StabilityFeeTreasuryForInternalCallsTest is StabilityFeeTreasury {
  constructor(
    address _safeEngine,
    address _extraSurplusReceiver,
    address _coinJoin,
    StabilityFeeTreasuryParams memory _sfTreasuryParams
  ) StabilityFeeTreasury(_safeEngine, _extraSurplusReceiver, _coinJoin, _sfTreasuryParams) {}

  event CalledJoinAllCoins();
  event CalledSettleDebt();

  // Functions to test internal calls
  function _joinAllCoins() internal virtual override {
    emit CalledJoinAllCoins();
  }

  function _settleDebt(
    uint256 _coinBalance,
    uint256 _debtBalance
  ) internal virtual override returns (uint256 _newCoinBalance, uint256 _newDebtBalance) {
    emit CalledSettleDebt();
    return (_coinBalance, _debtBalance);
  }
}

contract StabilityFeeTreasuryForTest is StabilityFeeTreasury {
  constructor(
    address _safeEngine,
    address _extraSurplusReceiver,
    address _coinJoin,
    StabilityFeeTreasuryParams memory _sfTreasuryParams
  ) StabilityFeeTreasury(_safeEngine, _extraSurplusReceiver, _coinJoin, _sfTreasuryParams) {}

  event CalledJoinAllCoins();
  event CalledSettleDebt();

  // Function to test internal method joinAllCoins
  function callJoinAllCoins() external {
    super._joinAllCoins();
  }
}
