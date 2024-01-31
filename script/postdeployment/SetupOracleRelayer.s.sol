// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Script.sol';
import '@script/Registry.s.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';

// BROADCAST
// source .env && forge script SetupOracleRelayerMainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script SetupOracleRelayerMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

/**
 * TODO: get oracleRelayer address on mainnet
 *
 * contract SetupOracleRelayerMainnet is Script {
 *   function run() public {
 *     vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));
 *     oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(MAINNET_SYSTEM_COIN_ORACLE));
 *     oracleRelayer.addAuthorization(MAINNET_TIMELOCK_CONTROLLER);
 *     oracleRelayer.removeAuthorization(vm.envAddress('ARB_MAINNET_DEPLOYER_PC'));
 *     vm.stopBroadcast();
 *   }
 * }
 */

// BROADCAST
// source .env && forge script SetupOracleRelayerSepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script SetupOracleRelayerSepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract SetupOracleRelayerSepolia is SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(SEPOLIA_SYSTEM_COIN_ORACLE));
    oracleRelayer.addAuthorization(SEPOLIA_TIMELOCK_CONTROLLER);
    oracleRelayer.removeAuthorization(vm.envAddress('ARB_SEPOLIA_DEPLOYER_PC'));
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script MockSetupOracleRelayer --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script MockSetupOracleRelayer --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract MockSetupOracleRelayer is SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(SEPOLIA_SYSTEM_COIN_ORACLE));
    vm.stopBroadcast();
  }
}
