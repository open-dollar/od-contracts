// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

contract SAFEHandler {
  constructor(address _safeEngine) {
    ISAFEEngine(_safeEngine).approveSAFEModification(msg.sender);
  }
}
