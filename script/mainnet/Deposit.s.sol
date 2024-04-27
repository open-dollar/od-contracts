// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MainnetScripts} from '@script/mainnet/MainnetScripts.s.sol';
import {WSTETH, ARB, RETH} from '@script/MainnetParams.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

// BROADCAST
// source .env && forge script DepositMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DepositMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DepositMainnet is MainnetScripts {
  function run() public prankSwitch(_user, USER1) {
    address proxy = address(deployOrFind(_user));

    uint256 safeId = 33;
    uint256 collateralWad = 1;
    depositCollat(WSTETH, safeId, 0.0524317028 ether, proxy);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}
