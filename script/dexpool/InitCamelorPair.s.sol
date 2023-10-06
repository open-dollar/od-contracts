// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';

// BROADCAST
// source .env && forge script InitCamelotPair --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script InitCamelotPair --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

// TODO: need to do initial deployment from PoolDeployer with a DataStorage address in order to initialize price
interface AlgebraPool {
  function initialize(uint160 initialPrice) external;
}

contract InitCamelotPair is LiquidityBase {
  address public pair;
  uint160 public initPrice = 300;

  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    pair = camelotV3Factory.poolByPair(tokenA, tokenB);
    AlgebraPool(0x536084B6dA763bE988cb1e0B509256cC22da2C36).initialize(initPrice);
    vm.stopBroadcast();
  }
}
