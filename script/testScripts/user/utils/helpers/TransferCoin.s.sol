// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script TransferCoin --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script TransferCoin --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC


//transfers system token from user2 to user1 to have extra COIN to repay debt
contract TransferCoin is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK2'));
    systemCoin.transfer(vm.envAddress('ARB_SEPOLIA_PUBLIC1'), 1 ether);
    vm.stopBroadcast();
  }
}