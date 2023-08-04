// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript} from './TestHelper.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// source .env && forge script DepositSafe --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

contract DepositSafe is TestHelperScript {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    address proxy = address(findOrDeploy(USER));
    uint256[] memory allSafes = safeManager.getSafes(proxy);
    uint256[] memory collatSafes = safeManager.getSafes(proxy, OP);

    depositCollat(2, WAD);
    vm.stopBroadcast();
  }

  function depositCollat(uint256 safeId, uint256 wad) public {
    basicActions.generateDebt(address(safeManager), taxCollector, coinJoin, safeId, wad);
  }
}

// getSafes
