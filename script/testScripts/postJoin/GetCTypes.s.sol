// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CTypeBase} from '@script/testScripts/postJoin/base/CTypeBase.s.sol';

// BROADCAST
// source .env && forge script GetCTypes --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script GetCTypes --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract GetCTypes is CTypeBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    collateralJoinFactory.collateralTypesList(); // bytes32 collateralTypes
    collateralAuctionHouseFactory.collateralList(); // bytes32 collateralTypes for collat auction
    vm.stopBroadcast();
  }
}
