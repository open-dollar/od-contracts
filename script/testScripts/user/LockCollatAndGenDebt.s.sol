// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';
import {MintableERC20} from '@contracts/for-test/MintableVoteERC20.sol';

// BROADCAST
// source .env && forge script LockCollAndGenDebt --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script LockCollAndGenDebt --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract LockCollAndGenDebt is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK2'));
    MintableERC20(address(WETH_TOKEN)).mint(USER2, 1_000_000 ether);

    address proxy = address(deployOrFind(USER2));
    WETH_TOKEN.approve(address(proxy), type(uint256).max);

    depositCollatAndGenDebt(WSTETH, SAFE, COLLATERAL, DEBT, proxy);
    vm.stopBroadcast();
  }
}
