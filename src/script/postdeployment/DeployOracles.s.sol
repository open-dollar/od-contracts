// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';

import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';
import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';

// BROADCAST
// source .env && forge script DeployOracles --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployOracles --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_GOERLI_RPC

contract DeployOracles is Script {
  IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(0x4893376342d5D7b3e31d4184c08b265e5aB2A3f6);

  UniV3Relayer public od_weth_UniV3Relayer;
  UniV3Relayer public odg_weth_UniV3Relayer;
  DenominatedOracle public weth_usd_denominatedOracle;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_GOERLI_PK'));
    od_weth_UniV3Relayer = uniswapV3Factory.
    odg_weth_UniV3Relayer = uniswapV3Factory
    weth_usd_denominatedOracle = new DenominatedOracle();
    vm.stopBroadcast();
  }
}
