// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Script.sol';
import '@script/Registry.s.sol';
import {OracleForTestnet} from '@contracts/for-test/OracleForTestnet.sol';

// BROADCAST
// source .env && forge script DeployTestnetOracle --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployTestnetOracle --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployTestnetOracle is Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    new OracleForTestnet(0.98 ether); // ~ 0.98 USD
    vm.stopBroadcast();
  }
}
