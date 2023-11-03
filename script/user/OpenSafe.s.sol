// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestScripts} from '@script/user/utils/TestScripts.s.sol';

// BROADCAST
// source .env && forge script OpenSafe --with-gas-price 2000000000 -vvvvv --chain-id 461614 --rpc-url $ARB_SEPOLIA_RPC --broadcast --verifier etherscan --verifier-url $SEPOLIA_API --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script OpenSafe --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract OpenSafe is TestScripts {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address proxy = address(deployOrFind(USER2));
    openSafe(WSTETH, proxy);
    vm.stopBroadcast();
  }
}

// source .env && forge script DeployGoerli --with-gas-price 2000000000 -vvvvv --chain-id 461614 --rpc-url $ARB_SEPOLIA_RPC --private-key $ARB_SEPOLIA_DEPLOYER_PK --broadcast --verifier etherscan --verifier-url $SEPOLIA_API --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY
