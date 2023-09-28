// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';
import {GOERLI_WETH} from '@script/Registry.s.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

// BROADCAST
// source .env && forge script RedeployRenderer --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RedeployRenderer --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract RedeployRenderer is GoerliDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    nftRenderer =
      new NFTRenderer(address(vault721), address(oracleRelayer), address(taxCollector), address(collateralJoinFactory));
    vm.stopBroadcast();
  }
}
