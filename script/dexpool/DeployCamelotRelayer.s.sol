// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';

// BROADCAST
// source .env && forge script DeployCamelotRelayer --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployCamelotRelayer --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract DeployCamelotRelayer is LiquidityBase {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    od_weth_CamelotRelayer = camelotRelayerFactory.deployCamelotRelayer(tokenA, tokenB, period);
    vm.stopBroadcast();
  }
}
