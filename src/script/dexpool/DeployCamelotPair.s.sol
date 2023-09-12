// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';

// BROADCAST
// source .env && forge script DeployCamelotPair --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployCamelotPair --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract DeployCamelotPair is LiquidityBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    camelotV3Factory.createPool(tokenA, tokenB);
    vm.stopBroadcast();
  }
}
