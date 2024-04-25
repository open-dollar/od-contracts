// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {HardcodedOracle} from '@contracts/for-test/HardcodedOracle.sol';

// BROADCAST
// source .env && forge script DeployStaticOracle --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployStaticOracle --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployStaticOracle is MainnetDeployment, Script, Test {
  address internal constant _DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;
  uint256 internal _deployerPk;
  address internal _deployer;

  address internal _initialSystemCoinOracle;

  modifier prankSwitch(address _caller, address _account) {
    bool _broadcast;
    if (_caller == _account) _broadcast = true;
    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_account);
    _;
    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }

  function setUp() public {
    _deployerPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    _deployer = vm.addr(_deployerPk);
  }

  function run() public prankSwitch(_deployer, _DEPLOYER) {
    _initialSystemCoinOracle = address(new HardcodedOracle('OD / USD', 1e18));
    emit log_named_address('SystemCoinOracle Address', _initialSystemCoinOracle);

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(_initialSystemCoinOracle));
  }
}
