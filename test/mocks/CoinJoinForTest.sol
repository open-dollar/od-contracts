// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CoinJoin, ICoinJoin} from '@contracts/utils/CoinJoin.sol';

contract CoinJoinForTest is CoinJoin {
  constructor(address _safeEngine, address _systemCoin) CoinJoin(_safeEngine, _systemCoin) {}

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }
}
