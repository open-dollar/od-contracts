// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {CollateralJoinFactory} from '@contracts/factories/CollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

// BROADCAST
// source .env && forge script JoinCType --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script JoinCType --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract JoinCType is GoerliContracts, Script {
  CollateralJoinFactory public collateralJoinFactory = CollateralJoinFactory(collateralJoinFactoryAddr);

  bytes32 public cType = vm.envBytes32('CTYPE_SYM');
  address public cAddr = vm.envAddress('CTYPE_ADDR');

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    ICollateralJoin cJoin = collateralJoinFactory.deployCollateralJoin(cType, cAddr);
    vm.stopBroadcast();
  }
}
