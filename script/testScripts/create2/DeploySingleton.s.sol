// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {OpenDollar, SystemCoin, ISystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

/**
 * @dev singleton contracts deployed prior to create2 factory deployment for etherscan verification
 */

// BROADCAST
// source .env && forge script DeploySingletonSepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeploySingletonSepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeploySingletonSepolia is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    new OpenDollarGovernance();
    new OpenDollar();
    new Vault721();
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeploySingletonMain --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeploySingletonMain --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeploySingletonMain is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));
    new OpenDollarGovernance();
    new OpenDollar();
    new Vault721();
    vm.stopBroadcast();
  }
}
