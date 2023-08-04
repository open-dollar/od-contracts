// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript} from './TestHelper.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {HaiProxyRegistry} from '@contracts/proxies/HaiProxyRegistry.sol';

// source .env && forge script FindOrDeployProxy --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

contract FindOrDeployProxy is TestHelperScript {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    findOrDeploy(USER);
    vm.stopBroadcast();
  }
}
