// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/testScripts/user/utils/TestScripts.s.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import 'forge-std/console2.sol';

// BROADCAST
// source .env && forge script RepayAllDebtAndFreeTokenCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RepayAllDebtAndFreeTokenCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract RepayAllDebtAndFreeTokenCollateral is TestScripts {
  /// @dev this script will pay off as much debt as it can with your availible COIN and then unlock as much Collateral as possible.
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER1));

    systemCoin.approve(proxy, type(uint256).max);

    repayAllDebtAndFreeTokenCollateral(WSTETH, SAFE, proxy);
    vm.stopBroadcast();
  }
}
