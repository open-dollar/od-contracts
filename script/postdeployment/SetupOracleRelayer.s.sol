// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {SEPOLIA_SYSTEM_COIN_ORACLE} from '@script/Registry.s.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';

// BROADCAST
// source .env && forge script SetupOracleRelayer --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script SetupOracleRelayer --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract SetupOracleRelayer is SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(SEPOLIA_SYSTEM_COIN_ORACLE));
    oracleRelayer.addAuthorization(address(timelockController));
    oracleRelayer.removeAuthorization(vm.envAddress('ARB_SEPOLIA_DEPLOYER_PC'));
    vm.stopBroadcast();
  }
}

contract MockSetupOracleRelayer is SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(SEPOLIA_SYSTEM_COIN_ORACLE));
    vm.stopBroadcast();
  }
}
