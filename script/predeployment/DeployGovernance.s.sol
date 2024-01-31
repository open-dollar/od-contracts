// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

// BROADCAST
// source .env && forge script DeployGovernanceMainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployGovernanceMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployGovernanceMainnet is Script {
  TimelockController internal _timelockController;
  ODGovernor internal _odGovernor;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));

    address deployer = vm.envAddress('ARB_MAINNET_DEPLOYER_PC');
    address[] memory members = new address[](0);

    _timelockController = new TimelockController(MIN_DELAY, members, members, deployer);

    _odGovernor = new ODGovernor(
      MAINNET_INIT_VOTING_DELAY,
      MAINNET_INIT_VOTING_PERIOD,
      MAINNET_INIT_PROP_THRESHOLD,
      MAINNET_PROTOCOL_TOKEN,
      _timelockController
    );

    // set odGovernor as PROPOSER_ROLE and EXECUTOR_ROLE
    _timelockController.grantRole(_timelockController.PROPOSER_ROLE(), address(_odGovernor));
    _timelockController.grantRole(_timelockController.EXECUTOR_ROLE(), address(_odGovernor));

    // // revoke deployer from TIMELOCK_ADMIN_ROLE
    _timelockController.renounceRole(_timelockController.TIMELOCK_ADMIN_ROLE(), deployer);

    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployGovernanceSepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployGovernanceSepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployGovernanceSepolia is Script {
  TimelockController internal _timelockController;
  ODGovernor internal _odGovernor;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));

    address deployer = vm.envAddress('ARB_SEPOLIA_DEPLOYER_PC');
    address[] memory members = new address[](0);

    _timelockController = new TimelockController(MIN_DELAY, members, members, deployer);

    _odGovernor = new ODGovernor(
      TEST_INIT_VOTING_DELAY,
      TEST_INIT_VOTING_PERIOD,
      TEST_INIT_PROP_THRESHOLD,
      SEPOLIA_PROTOCOL_TOKEN,
      _timelockController
    );

    // set odGovernor as PROPOSER_ROLE and EXECUTOR_ROLE
    _timelockController.grantRole(_timelockController.PROPOSER_ROLE(), address(_odGovernor));
    _timelockController.grantRole(_timelockController.EXECUTOR_ROLE(), address(_odGovernor));

    // // revoke deployer from TIMELOCK_ADMIN_ROLE
    _timelockController.renounceRole(_timelockController.TIMELOCK_ADMIN_ROLE(), deployer);

    vm.stopBroadcast();
  }
}
