// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {ODCreate2Factory} from '@contracts/factories/ODCreate2Factory.sol';

// BROADCAST
// source .env && forge script DeployODCreate2FactoryMain --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployODCreate2FactoryMain --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployODCreate2FactoryMainnet is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));
    new ODCreate2Factory();
    create2.addAuthorization(MAINNET_SAFE);
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployODCreate2FactorySepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployODCreate2FactorySepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployODCreate2FactorySepolia is Script {
  IODCreate2Factory internal create2;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    new ODCreate2Factory();
    create2.addAuthorization(TEST_SAFE);
    vm.stopBroadcast();
  }
}
