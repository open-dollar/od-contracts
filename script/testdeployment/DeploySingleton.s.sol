// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Script} from 'forge-std/Script.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {OpenDollar, SystemCoin, ISystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {BasicActions, CommonActions} from '@contracts/proxies/actions/BasicActions.sol';


// BROADCAST
// source .env && forge script DeployBasicActionsSingletonMain --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployBasicActionsSingletonMain --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployBasicActionsSingletonMain is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));
    new BasicActions();
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployProxySingletonMain --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProxySingletonMain --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployProxySingletonMain is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));
    new ODProxy(msg.sender);
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployAllSingletonMain --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployAllSingletonMain --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployAllSingletonMain is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));
    new OpenDollarGovernance();
    new OpenDollar();
    new Vault721();
    vm.stopBroadcast();
  }
}

/**
 * @dev singleton contracts deployed prior to create2 factory deployment for etherscan verification
 */

// BROADCAST
// source .env && forge script DeployAllSingletonSepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployAllSingletonSepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployAllSingletonSepolia is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    new OpenDollarGovernance();
    new OpenDollar();
    new Vault721();
    vm.stopBroadcast();
  }
}


