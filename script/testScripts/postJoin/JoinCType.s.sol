// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CTypeBase} from '@script/testScripts/postJoin/base/CTypeBase.s.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

// BROADCAST
// source .env && forge script JoinCType --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script JoinCType --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract JoinCType is CTypeBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    collateralJoinFactory.deployCollateralJoin(cType, cAddr); // ICollateralJoin
    vm.stopBroadcast();
  }
}
