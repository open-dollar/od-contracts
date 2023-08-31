// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {ARB_GOERLI_WETH} from '@script/Registry.s.sol';

import {DenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import {UniV3RelayerFactory} from '@contracts/factories/UniV3RelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

// BROADCAST
// source .env && forge script DeployOracles --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployOracles --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract DeployOracles is GoerliContracts, Script {
  UniV3RelayerFactory public uniV3RelayerFactory = UniV3RelayerFactory(uniV3RelayerFactoryAddr);
  DenominatedOracleFactory public denominatedOracleFactory = DenominatedOracleFactory(denominatedOracleFactoryAddr);

  address public OD_token = systemCoinAddr;
  address public ODG_token = protocolTokenAddr;
  address public WETH_token = ARB_GOERLI_WETH;

  uint24 public fee = uint24(0x2710);
  uint32 public period = uint32(1 days);

  IBaseOracle public od_weth_UniV3Relayer;
  IBaseOracle public odg_weth_UniV3Relayer;
  IBaseOracle public weth_usd_denominatedOracle;
  IBaseOracle public totem_weth_denominatedOracle;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    od_weth_UniV3Relayer = uniV3RelayerFactory.deployUniV3Relayer(OD_token, WETH_token, fee, period);
    odg_weth_UniV3Relayer = uniV3RelayerFactory.deployUniV3Relayer(ODG_token, WETH_token, fee, period);
    weth_usd_denominatedOracle = denominatedOracleFactory.deployDenominatedOracle(
      od_weth_UniV3Relayer, IBaseOracle(delayedOracleChild1Addr), false
    );
    vm.stopBroadcast();
  }
}
