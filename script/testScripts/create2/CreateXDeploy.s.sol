// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Create2Factory} from '@contracts/utils/Create2Factory.sol';

// BROADCAST
// source .env && forge script CreateXDeploy --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script CreateXDeploy --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract CreateXDeploy is Script {
  Create2Factory create2Factory = Create2Factory(SEPOLIA_CREATE2_FACTORY);

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    create2Factory.deployProtocolToken(SEPOLIA_SALT_PROTOCOLTOKEN);
    create2Factory.deploySystemCoin(SEPOLIA_SALT_SYSTEMCOIN);
    create2Factory.deployVault721(SEPOLIA_SALT_VAULT721);
    vm.stopBroadcast();
  }
}
