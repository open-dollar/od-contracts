// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/console.sol';
import {AnvilFork} from '@testlocal/nft/anvil/AnvilFork.t.sol';
import {Script} from 'forge-std/Script.sol';
import {J, P} from '@script/Registry.s.sol';

contract DebtState is AnvilFork, Script {
  function warpAndUpdatePriceFeeds() public {
    // warp time and update the price feeds
    for (uint256 i = 0; i < delayedOracles.length; i++) {
      vm.warp(block.timestamp + 1 days);
      delayedOracles[i].updateResult();
    }
  }

  function setPriceLowToTriggerDebtScenario() public {
    // change the wstETH delayed oracle price very low
    for (uint256 i = 0; i < testOracles.length - 1; i++) {
      vm.prank(J);
      testOracles[i + 1].setPriceAndValidity(1_000_000, true);
    }

    delayedOracles[0].updateDelay();

    // update all the denominatedOracles
    for (uint256 i = 0; i < denominatedOracles.length; i++) {
      denominatedOracles[i].getResultWithValidity();
      delayedOracles[i].getResultWithValidity();
    }

    for (uint256 i = 0; i < 2; i++) {
      warpAndUpdatePriceFeeds();
    }

    for (uint256 i = 0; i < cTypes.length; i++) {
      // call updateCollateralPrice on the oracle relayer
      oracleRelayer.updateCollateralPrice(cTypes[i]);
    }
  }

  function run() public virtual {
    setPriceLowToTriggerDebtScenario();
  }

  // forge script script/states/DebtState.s.sol:DebtState --fork-url http://localhost:8545 -vvvvv
}
