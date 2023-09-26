// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';

// BROADCAST
// source .env && forge script DeployErrors --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployErrors --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract DeployErrors is GoerliDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    basicActions = new BasicActions();
    nftRenderer = new NFTRenderer(
      address(vault721),
      address(oracleRelayer),
      address(taxCollector),
      address(collateralJoinFactory)
    );
    globalSettlementActions = new GlobalSettlementActions();
    vm.stopBroadcast();
  }
}
