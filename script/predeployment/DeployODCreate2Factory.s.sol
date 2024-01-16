// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {ODCreate2Factory} from '@contracts/factories/ODCreate2Factory.sol';

// BROADCAST
// source .env && forge script DeployODCreate2FactoryMainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployODCreate2FactoryMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployODCreate2FactoryMainnet is Script {
  ODCreate2Factory internal create2;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_ADMIN_PK'));
    create2 = new ODCreate2Factory(MAINNET_DEPLOYER);
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployODCreate2FactorySepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployODCreate2FactorySepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployODCreate2FactorySepolia is Script {
  ODCreate2Factory internal create2;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    create2 = new ODCreate2Factory(vm.envAddress('ARB_SEPOLIA_PC'));
    vm.stopBroadcast();
  }
}
