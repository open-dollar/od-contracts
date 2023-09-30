// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

// BROADCAST
// source .env && forge script DeployDenominatedOracleCamelotV3 --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployDenominatedOracleCamelotV3 --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract DeployDenominatedOracleCamelotV3 is LiquidityBase {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    denominatedOracleFactory.deployDenominatedOracle(
      IBaseOracle(0x97eDe6FFaaA866a749bc230B2aDF7B86Ba7a9946), IBaseOracle(DelayedOracleChild_WSTETH_Address), false
    );
    vm.stopBroadcast();
  }
}
