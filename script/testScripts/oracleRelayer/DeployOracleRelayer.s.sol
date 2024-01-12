// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';
import {OracleRelayer, IOracleRelayer} from '@contracts/OracleRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {RAY, WAD} from '@libraries/Math.sol';

// BROADCAST
// source .env && forge script DeployOracleRelayer --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployOracleRelayer --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployOracleRelayer is SepoliaDeployment, Script, Test {
  OracleRelayer internal _oracleRelayer;
  IOracleRelayer.OracleRelayerParams internal _oracleRelayerCustomParams;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));

    _oracleRelayerCustomParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: RAY * WAD, // unbounded
      redemptionRateLowerBound: 1 // unbounded
    });

    emit log_named_address('SafeEngine', address(safeEngine));
    emit log_named_address('SystemOracle', SEPOLIA_SYSTEM_COIN_ORACLE);

    _oracleRelayer =
      new OracleRelayer(address(safeEngine), IBaseOracle(SEPOLIA_SYSTEM_COIN_ORACLE), _oracleRelayerCustomParams);

    _oracleRelayer.addAuthorization(H);
    _oracleRelayer.addAuthorization(P);

    vm.stopBroadcast();
  }
}
