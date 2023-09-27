// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/user/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script LockCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script LockCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract LockCollateral is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    address proxy = address(deployOrFind(USER2));
    WETH_TOKEN.approve(proxy, type(uint256).max);

    depositCollatAndGenDebt(WSTETH, SAFE, COLLATERAL, ZERO_DEBT, proxy);
    vm.stopBroadcast();
  }
}
