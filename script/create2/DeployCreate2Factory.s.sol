// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {Create2Factory} from '@contracts/utils/Create2Factory.sol';

// BROADCAST
// source .env && forge script DeployCreate2Factory --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployCreate2Factory --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

// ANVIL
// source .env && forge script DeployCreate2FactoryAnvil --with-gas-price 2000000000 -vvvvv --rpc-url $ANVIL_RPC --broadcast

contract DeployCreate2Factory is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    new Create2Factory();
    vm.stopBroadcast();
  }
}

contract DeployCreate2FactoryAnvil is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ANVIL_ONE'));
    new Create2Factory();
    vm.stopBroadcast();
  }
}
