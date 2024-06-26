// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';
import 'forge-std/console2.sol';
// BROADCAST
// source .env && forge script GetSafes --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast

// SIMULATE
// source .env && forge script GetSafes --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract GetSafes is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_PK'));
    address usr = vm.addr(vm.envUint('ARB_MAINNET_PK'));
    address proxy = deployOrFind(usr);
    uint256[] memory _safes = safeManager.getSafes(proxy);
    console2.log(address(WETH_TOKEN));
    console2.log(WETH_TOKEN.balanceOf(usr));
    console2.log('address: ', usr);
    for (uint256 i = 0; i < _safes.length;) {
      safeManager.safeData(_safes[i]);
      console2.log('safe', _safes[i]);
      ++i;
    }
    vm.stopBroadcast();
  }
}
