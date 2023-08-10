// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript1} from '@script/test/utils/TestHelper1.s.sol';
import {TestHelperScript2} from '@script/test/utils/TestHelper2.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {HaiProxyRegistry} from '@contracts/proxies/HaiProxyRegistry.sol';

// source .env && forge script DeployOrFindProxy --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

contract DeployOrFindProxy is TestHelperScript2 {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    deployOrFind(USER2);
    vm.stopBroadcast();
  }
}
