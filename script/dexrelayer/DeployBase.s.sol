// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GOERLI_WETH, GOERLI_ALGEBRA_FACTORY} from '@script/Registry.s.sol';
import {IAlgebraFactory} from '@cryptoalgebra-core/interfaces/IAlgebraFactory.sol';
import {CamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';
import {DenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import {ChainlinkRelayerFactory, IChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

contract DeployBase is Script {
  IAlgebraFactory public algebraFactory = IAlgebraFactory(GOERLI_ALGEBRA_FACTORY);
  ChainlinkRelayerFactory public chainlinkRelayerFactory = ChainlinkRelayerFactory(ChainlinkRelayerFactory_Address);
  CamelotRelayerFactory public camelotRelayerFactory = CamelotRelayerFactory(CamelotRelayerFactory_Address);
  DenominatedOracleFactory public denominatedOracleFactory = DenominatedOracleFactory(DenominatedOracleFactory_Address);

  /**
   * TODO:
   * create deploy script, contract addresse, and contract deployment files for fork testing on Goerli
   * -- limited to Algebra contracts (already deployed) and relayer
   *
   * 1. save existing Algebra infrastructure in vars
   * 2. get chainlink price feed
   * 3. deploy relayer and denominated oracles
   * 4. create scipts for all basic functions
   * 5. create tests using scripts
   */
}
