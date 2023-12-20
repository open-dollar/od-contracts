// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AnvilFork} from '@testlocal/nft/anvil/AnvilFork.t.sol';
import {Script} from 'forge-std/Script.sol';
import {J, P} from '@script/Registry.s.sol';

contract DebtState is AnvilFork, Script {

  function setPriceLowToTriggerDebtScenario() public {

    vm.prank(J);
    // change the wstETH delayed oracle price very low
    testOracles[0].setPriceAndValidity(1, true);

    // update all the denominatedOracles
    for (uint256 i = 0; i < denominatedOracles.length; i++) {
      denominatedOracles[i].getResultWithValidity();
    }

    for (uint256 i = 0; i < cTypes.length; i++) {
      // call updateCollateralPrice on the oracle relayer
      oracleRelayer.updateCollateralPrice(cTypes[i]);
    }

  }

  function run() public {
    setUp();
    setPriceLowToTriggerDebtScenario();
  }

  // forge script script/states/DebtState.s.sol:DebtState --fork-url http://localhost:8545 -vvvvv
}
