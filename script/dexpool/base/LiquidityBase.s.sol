// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {IAlgebraFactory} from '@cryptoalgebra-i-core/IAlgebraFactory.sol';
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
  GOERLI_CAMELOT_V3_FACTORY
} from '@script/Registry.s.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

contract LiquidityBase is GoerliContracts, Script {
  IAlgebraFactory public camelotV3Factory = IAlgebraFactory(GOERLI_CAMELOT_V3_FACTORY);
  CamelotRelayerFactory public camelotRelayerFactory = CamelotRelayerFactory(CamelotRelayerFactory_Address);
  DenominatedOracleFactory public denominatedOracleFactory = DenominatedOracleFactory(DenominatedOracleFactory_Address);

  address public OD_token = SystemCoin_Address;
  address public ODG_token = ProtocolToken_Address;
  address public WETH_token = GOERLI_WETH;

  // TODO: change to .env variable
  address public tokenA = OD_token;
  address public tokenB = WETH_token;

  uint24 public fee = uint24(0x2710);
  uint32 public period = uint32(1 days);

  IBaseOracle public od_weth_CamelotRelayer;
}
