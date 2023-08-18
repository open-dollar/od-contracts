// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/test/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script LockCollAndGenDebt --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script LockCollAndGenDebt --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC

contract LockCollAndGenDebt is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    address proxy = address(deployOrFind(USER2));
    WETH_TOKEN.approve(address(proxy), type(uint256).max);

    depositCollatAndGenDebt(WETH, 12, 0.4 ether, 200 ether, proxy);
    vm.stopBroadcast();
  }
}
