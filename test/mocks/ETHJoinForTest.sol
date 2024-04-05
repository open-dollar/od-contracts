// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ETHJoin, IETHJoin} from '@contracts/utils/ETHJoin.sol';

contract ETHJoinForTest is ETHJoin {
  constructor(address _safeEngine, bytes32 _cType) ETHJoin(_safeEngine, _cType) {}

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }
}
