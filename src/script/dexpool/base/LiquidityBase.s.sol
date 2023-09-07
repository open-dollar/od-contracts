// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {ICamelotFactory} from '@camelot/interfaces/ICamelotFactory.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3PoolDeployer} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol';
import {IPoolInitializer} from '@uniswap/v3-periphery/contracts/interfaces/IPoolInitializer.sol';
import {ARB_GOERLI_WETH, GOERLI_UNISWAP_V3_FACTORY, GOERLI_CAMELOT_FACTORY} from '@script/Registry.s.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';

contract LiquidityBase is GoerliContracts, Script {
  IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(GOERLI_UNISWAP_V3_FACTORY);
  ICamelotFactory public camelotFactory = ICamelotFactory(GOERLI_CAMELOT_FACTORY);

  address public tokenA = systemCoinAddr;
  address public tokenB = ARB_GOERLI_WETH;
  uint24 public fee = uint24(0x2710);
}
