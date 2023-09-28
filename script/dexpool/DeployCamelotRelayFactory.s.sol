// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {CamelotRelayerFactory, ICamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';

// BROADCAST
// source .env && forge script DeployCamelotRelayFactory --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployCamelotRelayFactory --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract DeployCamelotRelayFactory is LiquidityBase {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    camelotRelayerFactory = new CamelotRelayerFactory();
    vm.stopBroadcast();
  }
}
