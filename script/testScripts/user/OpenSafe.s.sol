// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script OpenSafe --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast

// SIMULATE
// source .env && forge script OpenSafe --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract OpenSafe is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER2));
    openSafe(WSTETH, proxy);
    vm.stopBroadcast();
  }
}
