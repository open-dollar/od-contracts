// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {Script} from 'forge-std/Script.sol';
import {VerifyParams} from './VerifyParams.s.sol';

// BROADCAST
// source .env && forge script VerifySepoliaParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script VerifySepoliaParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

// TODO add mainnet verification when deployment happens

contract VerifySepoliaParams is VerifyParams, SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    _getEnvironmentParams();
    _verifyParams();
    _verifyCollateralParams();
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script VerifyMainnetParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script VerifyMainnetParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

// TODO add mainnet verification when deployment happens


contract VerifyMainnetParams is VerifyParams, MainnetDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_PK'));
    _getEnvironmentParams();
    _verifyParams();
    _verifyCollateralParams();
    vm.stopBroadcast();
  }
}
