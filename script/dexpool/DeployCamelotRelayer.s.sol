// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {GOERLI_CAMELOT_V3_FACTORY} from '@script/Registry.s.sol';

// BROADCAST
// source .env && forge script DeployCamelotRelayer --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployCamelotRelayer --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployCamelotRelayer is LiquidityBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    od_weth_CamelotRelayer =
      camelotRelayerFactory.deployCamelotRelayer(GOERLI_CAMELOT_V3_FACTORY, tokenA, tokenB, period);
    vm.stopBroadcast();
  }
}
