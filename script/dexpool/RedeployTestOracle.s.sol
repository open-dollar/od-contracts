// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {OracleForTestnet} from '@contracts/for-test/OracleForTestnet.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAlgebraPool} from '@cryptoalgebra-core/interfaces/IAlgebraPool.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICamelotRelayer} from '@interfaces/oracles/ICamelotRelayer.sol';
import {ChainlinkRelayerFactory, IChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';
import {CamelotRelayerFactory, ICamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';
import {DenominatedOracleFactory, IDenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import '@script/Registry.s.sol';
import '@script/GoerliDeployment.s.sol';

// BROADCAST
// source .env && forge script ReDeployTestOracle --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script ReDeployTestOracle --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract ReDeployTestOracle is GoerliDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    systemCoinOracle = new OracleForTestnet(1e18); // 1 OD = 1 USD 'OD / USD'

    // not authorized to modify params
    // oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(systemCoinOracle));
    vm.stopBroadcast();
  }
}
