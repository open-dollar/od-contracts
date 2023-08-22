// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';

import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {PostSettlementSurplusBidActions} from '@contracts/proxies/actions/PostSettlementSurplusBidActions.sol';
import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

// BROADCAST
// source .env && forge script DeployNewProxies --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployNewProxies --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract DeployNewProxies is Script {
  GlobalSettlementActions public globalSettlementActions;
  PostSettlementSurplusBidActions public postSettlementSurplusBidActions;
  CommonActions public commonActions;

  function run() public {
    newProxies();
    modifiedProxies();
  }

  function newProxies() public {
    globalSettlementActions = new GlobalSettlementActions();
    postSettlementSurplusBidActions = new PostSettlementSurplusBidActions();
  }

  function modifiedProxies() public {
    commonActions = new CommonActions();
  }
}
