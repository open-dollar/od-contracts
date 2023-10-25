// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {IAlgebraFactory} from '@cryptoalgebra-core/interfaces/IAlgebraFactory.sol';
import {CamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3PoolDeployer} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol';
import {UniV3RelayerFactory} from '@contracts/factories/UniV3RelayerFactory.sol';
import {IPoolInitializer} from '@uniswap/v3-periphery/contracts/interfaces/IPoolInitializer.sol';
import {DenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import {
  GOERLI_WETH,
  GOERLI_UNISWAP_V3_FACTORY,
  GOERLI_CAMELOT_V2_FACTORY,
  GOERLI_ALGEBRA_FACTORY
} from '@script/Registry.s.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ChainlinkRelayerFactory, IChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';

contract LiquidityBase is GoerliContracts, Script {
  IAlgebraFactory public algebraFactory = IAlgebraFactory(GOERLI_ALGEBRA_FACTORY);
  ChainlinkRelayerFactory public chainlinkRelayerFactory = ChainlinkRelayerFactory(ChainlinkRelayerFactory_Address);
  CamelotRelayerFactory public camelotRelayerFactory = CamelotRelayerFactory(CamelotRelayerFactory_Address);
  DenominatedOracleFactory public denominatedOracleFactory = DenominatedOracleFactory(DenominatedOracleFactory_Address);

  address public tokenA = SystemCoin_Address;
  address public tokenB = GOERLI_WETH;

  uint24 public fee = uint24(0x2710);
  uint32 public period = uint32(1 days);

  IBaseOracle public od_weth_CamelotRelayer;
}
