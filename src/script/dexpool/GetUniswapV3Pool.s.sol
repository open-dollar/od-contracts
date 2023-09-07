// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3PoolDeployer} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol';
import {IPoolInitializer} from '@uniswap/v3-periphery/contracts/interfaces/IPoolInitializer.sol';
import {ARB_GOERLI_WETH} from '@script/Registry.s.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';

// BROADCAST
// source .env && forge script GetUniswapV3Pool --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script GetUniswapV3Pool --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract GetUniswapV3Pool is GoerliContracts, Script {
  IUniswapV3Factory public camelotFactory = IUniswapV3Factory(0x659fd9F4536f540bd051c2739Fc8b8e9355E5042);
  address public tokenA = systemCoinAddr;
  address public tokenB = ARB_GOERLI_WETH;
  uint24 public fee = uint24(0x2710);

  address public pool;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    pool = uniswapV3Factory.getPool(tokenA, tokenB, fee);
    vm.stopBroadcast();
  }
}
