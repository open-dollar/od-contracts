// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {CamelotRelayerFactory, ICamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';

// BROADCAST
// source .env && forge script DeployCamelotRelayFactory --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployCamelotRelayFactory --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployCamelotRelayFactory is LiquidityBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    camelotRelayerFactory = new CamelotRelayerFactory();
    vm.stopBroadcast();
  }
}
