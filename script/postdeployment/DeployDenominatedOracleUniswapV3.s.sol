// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {OracleBase} from '@script/postdeployment/base/OracleBase.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

// BROADCAST
// source .env && forge script DeployDenominatedOracleUniswapV3 --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployDenominatedOracleUniswapV3 --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract DeployDenominatedOracleUniswapV3 is OracleBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    weth_usd_denominatedOracle = denominatedOracleFactory.deployDenominatedOracle(
      od_weth_UniV3Relayer,
      IBaseOracle(DelayedOracleChild_WETH_Address),
      false
    );
    vm.stopBroadcast();
  }
}
