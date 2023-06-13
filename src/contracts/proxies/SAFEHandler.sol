// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SAFEEngine} from '@contracts/SAFEEngine.sol';

contract SAFEHandler {
  constructor(address _safeEngine) {
    SAFEEngine(_safeEngine).approveSAFEModification(msg.sender);
  }
}
