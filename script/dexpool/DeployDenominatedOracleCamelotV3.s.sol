// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

// BROADCAST
// source .env && forge script DeployDenominatedOracleCamelotV3 --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployDenominatedOracleCamelotV3 --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract DeployDenominatedOracleCamelotV3 is LiquidityBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    denominatedOracleFactory.deployDenominatedOracle(
      IBaseOracle(0x97eDe6FFaaA866a749bc230B2aDF7B86Ba7a9946), IBaseOracle(DelayedOracleChild_WETH_Address), false
    );
    vm.stopBroadcast();
  }
}
