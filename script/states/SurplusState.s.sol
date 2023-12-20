// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AnvilFork} from '@testlocal/nft/anvil/AnvilFork.t.sol';
import {Script} from 'forge-std/Script.sol';

contract DebtState is AnvilFork, Script {
  function run() public {
    setUp();
  }
}
