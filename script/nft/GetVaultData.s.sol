// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

// BROADCAST
// source .env && forge script GetVaultData --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script GetVaultData --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract GetVaultData is GoerliDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    vault721.tokenURI(2);
    vm.stopBroadcast();
  }
}
