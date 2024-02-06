// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script RepayDebt --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RepayDebt --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract RepayDebt is TestScripts {
  uint256 public debtToRepay = 1_000_000_000; //replace this with whatever amount of debt you'd like to repay

  /// @dev this script will pay off as much debt as it can with your availible COIN and then unlock as much Collateral as possible.
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER1));

    systemCoin.approve(proxy, type(uint256).max);

    repayDebt(SAFE, debtToRepay, proxy);
    vm.stopBroadcast();
  }
}
