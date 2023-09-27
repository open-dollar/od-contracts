// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {CTypeBase} from '@script/postdeployment/base/CTypeBase.s.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

// BROADCAST
// source .env && forge script JoinCType --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script JoinCType --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract JoinCType is CTypeBase {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    ICollateralJoin cJoin = collateralJoinFactory.deployCollateralJoin(cType, cAddr);
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(cType, _cahCParams);
    vm.stopBroadcast();
  }
}
