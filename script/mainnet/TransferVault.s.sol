// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MainnetScripts} from '@script/mainnet/MainnetScripts.s.sol';

// BROADCAST
// source .env && forge script TransferVaultMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script TransferVaultMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract TransferVaultMainnet is MainnetScripts {
  function run() public prankSwitch(_user, USER1) {
    vault721.transferFrom(USER1, USER2, SAFE);
  }
}
