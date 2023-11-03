// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {OracleBase} from '@script/postdeployment/base/OracleBase.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

// BROADCAST
// source .env && forge script DeployOracleOD --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployOracleOD --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployOracleOD is OracleBase {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    od_weth_UniV3Relayer = uniV3RelayerFactory.deployUniV3Relayer(OD_token, WETH_token, fee, period);
    vm.stopBroadcast();
  }
}
