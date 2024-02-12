// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script LockCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script LockCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract LockCollateral is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER1));
    WETH_TOKEN.approve(proxy, type(uint256).max);

    depositCollatAndGenDebt(WSTETH, SAFE, COLLATERAL, ZERO_DEBT, proxy);
    vm.stopBroadcast();
  }
}
