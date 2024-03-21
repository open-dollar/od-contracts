// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Script.sol';
import '@script/Registry.s.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';
import {PIDRateSetter} from '@contracts/PIDRateSetter.sol';

// BROADCAST
// source .env && forge script UpdateRate --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script UpdateRate --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract UpdateRate is SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    pidRateSetter.updateRate();
    vm.stopBroadcast();
  }
}
