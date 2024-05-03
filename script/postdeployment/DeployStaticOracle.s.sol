// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {PrankSwitch} from '@script/utils/PrankSwitch.s.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {HardcodedOracle} from '@contracts/for-test/HardcodedOracle.sol';

// BROADCAST
// source .env && forge script DeployStaticOracle --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployStaticOracle --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployStaticOracle is MainnetDeployment, PrankSwitch {
  address internal _initialSystemCoinOracle;

  function run() public prankSwitch(MAINNET_TIMELOCK_CONTROLLER) {
    _initialSystemCoinOracle = address(new HardcodedOracle('OD / USD', 1e18));
    emit log_named_address('SystemCoinOracle Address', _initialSystemCoinOracle);

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(_initialSystemCoinOracle));
  }
}
