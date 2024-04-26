// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MainnetScripts} from '@script/mainnet/MainnetScripts.s.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {WSTETH, ARB, RETH} from '@script/MainnetParams.s.sol';

// BROADCAST
// source .env && forge script RepayDebtMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RepayDebtMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract RepayDebtMainnet is MainnetScripts {
  function run() public prankSwitch(_user, USER1) {
    address proxy = address(deployOrFind(_user));

    basicActions = new BasicActions();

    systemCoin.approve(proxy, type(uint256).max);
    uint256 safeId = 24;
    uint256 collateralWad = 1;

    // repayAllDebt(safeId, proxy);
    repayAllDebtAndFreeTokenCollateral(RETH, safeId, proxy, collateralWad);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}
