// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AnvilFork} from '@testlocal/nft/anvil/AnvilFork.t.sol';
import {Script} from 'forge-std/Script.sol';
import 'forge-std/Console.sol';

contract SurplusState is AnvilFork, Script {
  function run() public virtual {
    setUp();
    vm.warp(block.timestamp + 365 days);
    taxCollector.taxMany(0, 3);
    uint256 coinBalance = safeEngine.coinBalance(address(accountingEngine));
    uint256 debtBalance = safeEngine.debtBalance(address(accountingEngine));

    console.log('Coin Balance of Accounting Engine');
    console.logUint(coinBalance);
    console.log('Debt Balance of Accounting Engine');
    console.logUint(debtBalance);
  }
  // forge script script/states/SurplusState.s.sol:SurplusState --fork-url http://localhost:8545 -vvvvv
}
