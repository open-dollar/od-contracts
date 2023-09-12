// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {ICamelotFactory} from '@camelot/interfaces/ICamelotFactory.sol';
import {IAlgebraFactory as ICamelotV3Factory} from '@interfaces/factories/IAlgebraFactory.sol';
import {CamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3PoolDeployer} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol';
import {UniV3RelayerFactory} from '@contracts/factories/UniV3RelayerFactory.sol';
import {IPoolInitializer} from '@uniswap/v3-periphery/contracts/interfaces/IPoolInitializer.sol';
import {DenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import {
  ARB_GOERLI_WETH,
  GOERLI_UNISWAP_V3_FACTORY,
  GOERLI_CAMELOT_V2_FACTORY,
  GOERLI_CAMELOT_V3_FACTORY
} from '@script/Registry.s.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

contract LiquidityBase is GoerliContracts, Script {
  IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(GOERLI_UNISWAP_V3_FACTORY);
  ICamelotFactory public camelotV2Factory = ICamelotFactory(GOERLI_CAMELOT_V2_FACTORY);
  ICamelotV3Factory public camelotV3Factory = ICamelotV3Factory(GOERLI_CAMELOT_V3_FACTORY);
  CamelotRelayerFactory public camelotRelayerFactory = CamelotRelayerFactory(camelotRelayerFactoryAddr);
  UniV3RelayerFactory public uniV3RelayerFactory = UniV3RelayerFactory(uniV3RelayerFactoryAddr);
  DenominatedOracleFactory public denominatedOracleFactory = DenominatedOracleFactory(denominatedOracleFactoryAddr);

  address public OD_token = systemCoinAddr;
  address public ODG_token = protocolTokenAddr;
  address public WETH_token = ARB_GOERLI_WETH;

  // TODO: change to .env variable
  address public tokenA = OD_token;
  address public tokenB = WETH_token;

  uint24 public fee = uint24(0x2710);
  uint32 public period = uint32(1 days);

  IBaseOracle public od_weth_CamelotRelayer;
}
