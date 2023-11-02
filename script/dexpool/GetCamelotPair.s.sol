// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';

// BROADCAST
// source .env && forge script GetCamelotPair --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script GetCamelotPair --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract GetCamelotPair is LiquidityBase {
  address public pair;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    pair = camelotV3Factory.poolByPair(tokenA, tokenB);
    vm.stopBroadcast();
  }
}
