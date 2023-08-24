// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3PoolDeployer} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol';
import {IPoolInitializer} from '@uniswap/v3-periphery/contracts/interfaces/IPoolInitializer.sol';
import {ARB_GOERLI_WETH} from '@script/Registry.s.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';

// BROADCAST
// source .env && forge script GetLiqPool --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script GetLiqPool --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract GetLiqPool is GoerliContracts, Script {
  IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(0x4893376342d5D7b3e31d4184c08b265e5aB2A3f6);
  address public tokenB = ARB_GOERLI_WETH;
  address public tokenA = systemCoinAddr;
  uint24 public fee = uint24(0x2710);

  address public pool;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    pool = uniswapV3Factory.getPool(tokenA, tokenB, fee);
    vm.stopBroadcast();
  }
}
