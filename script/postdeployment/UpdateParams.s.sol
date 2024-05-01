// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import 'forge-std/console2.sol';

/**
 * @dev update to desired values:
 *  _NEW_GAS_LIMIT,
 *  _NEW_PROPORTIONAL_GAIN,
 *  _NEW_INTEGRAL_GAIN
 */
abstract contract Base is MainnetDeployment, Script {
  address internal constant _DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;
  uint256 internal constant _NEW_GAS_LIMIT = 10_000_000;
  int256 internal constant _NEW_PROPORTIONAL_GAIN = 3_160_000_000_000; // kp
  int256 internal constant _NEW_INTEGRAL_GAIN = 316_000; // ki

  uint256 internal _deployerPk;
  address internal _deployer;
  bool internal _broadcast;

  modifier prankSwitch(bool b) {
    if (b) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_DEPLOYER);
    _;
    if (b) vm.stopBroadcast();
    else vm.stopPrank();
  }

  function setUp() public {
    _deployerPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    _deployer = vm.addr(_deployerPk);
    if (_deployer == _DEPLOYER) _broadcast = true;
  }
}

// BROADCAST
// source .env && forge script UpdatePiParams --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script UpdatePiParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract UpdatePiParams is Base {
  function run() public prankSwitch(_broadcast) {
    bytes memory kpData = abi.encode(_NEW_PROPORTIONAL_GAIN);
    bytes memory kiData = abi.encode(_NEW_INTEGRAL_GAIN);

    pidController.modifyParameters('kp', kpData);
    pidController.modifyParameters('ki', kiData);
  }
}

// BROADCAST
// source .env && forge script UpdateLiquidationEngineParams --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script UpdateLiquidationEngineParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract UpdateLiquidationEngineParams is Base {
  function run() public prankSwitch(_broadcast) {
    bytes memory data = abi.encode(_NEW_GAS_LIMIT);

    liquidationEngine.modifyParameters('saviourGasLimit', data);
  }
}

// BROADCAST
// source .env && forge script UpdateTimelockMinDelay --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script UpdateTimelockMinDelay --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract UpdateTimelockMinDelay is Base {
  function run() public prankSwitch(_broadcast) {
    uint256 _newDelay = 3600;

    address[] memory targets = new address[](1);
    {
      targets[0] = address(timelockController);
    }
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
    }
    bytes[] memory calldatas = new bytes[](1);
    {
      calldatas[0] = abi.encodeWithSelector(TimelockController.updateDelay.selector, _newDelay);
    }

    timelockController.schedule(targets[0], values[0], calldatas[0], bytes32(0), bytes32(0), 0);
    timelockController.execute(targets[0], values[0], calldatas[0], bytes32(0), bytes32(0));

    uint256 newMinDelay = timelockController.getMinDelay();
    console2.log(newMinDelay);
    assert(newMinDelay == _newDelay);
  }
}
