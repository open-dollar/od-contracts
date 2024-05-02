// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MainnetScripts} from '@script/mainnet/MainnetScripts.s.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {WSTETH, ARB, RETH} from '@script/MainnetParams.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import 'forge-std/console2.sol';
// ANVIL
// source .env && anvil --rpc-url $ARB_MAINNET_RPC
// source .env && forge script TestGenerate --with-gas-price 2000000000 -vvvvv --rpc-url $ANVIL_RPC --unlocked

contract TestGenerate is MainnetScripts {
  function run() public {
    vm.startBroadcast(USER1);
    address proxy = address(deployOrFind(USER1));
    basicActions = new BasicActions();

    //open safe one
    uint256 safeId = openSafe(RETH, proxy);
    IERC20(_reth_Address).approve(proxy, type(uint256).max);
    depositCollatAndGenDebt(RETH, safeId, 10 ether, 1000 ether, proxy);
    // open safe 2 to get more OD
    // uint256 safeId2 = openSafe(RETH, proxy);
    // depositCollatAndGenDebt(RETH, safeId2, 150 ether, 200 ether, proxy);
    uint256 balance = systemCoin.balanceOf(USER1);
    console2.log('Ending balance: ', balance);
    // assert(balance == 200 ether);

    vm.stopBroadcast();
  }
}

/**
 * 0xEff45E8e2353893BD0558bD5892A42786E9142F1::modifySAFECollateralization(0x5245544800000000000000000000000000000000000000000000000000000000, SAFEHandler: [0xD79b87bc3EB61B086d647c42EA7c1d70952c0c50], SAFEHandler: [0xD79b87bc3EB61B086d647c42EA7c1d70952c0c50], SAFEHandler: [0xD79b87bc3EB61B086d647c42EA7c1d70952c0c50], 0, -199987022715481439548 [-1.999e20])
 */
