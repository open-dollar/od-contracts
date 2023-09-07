// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

// BROADCAST
// source .env && forge script GetVaultData --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script GetVaultData --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract GetVaultData is GoerliDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    vault721.tokenURI(2);
    vm.stopBroadcast();
  }
}

// WETH = 5745544800000000000000000000000000000000000000000000000000000000
// handler = 0x945bffee006693ee9569987776aa7f0524e64f90
// tokenID = 2
// collat = 00000000000000000000000000000000000000000000000002c68af0bb14 = 3051757812500
// debt = 00000000000000000000000000000000000000000000000000056acaa1899f89ba92 = 99.928860894322866834
// ratio = 0000000000000000000000000000000000000000045cb19ea48cad1f06 = 80.466270446777343750
// fee = 0000000000000000000000000000000000000000000000033b2e3cb54902c69f59a000 = 1000000001.547130000000000000
