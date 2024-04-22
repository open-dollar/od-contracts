// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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

    address deployer = vm.envAddress('ARB_MAINNET_DEPLOYER_ADDR');

    // empty address array for Proposers and Executors (ODGovernor will assume these roles)
    address[] memory members = new address[](0);

    _timelockController = TimelockController(payable(MAINNET_TIMELOCK_CONTROLLER));

    _odGovernor = new ODGovernor(
      MAINNET_INIT_VOTING_DELAY,
      MAINNET_INIT_VOTING_PERIOD,
      MAINNET_INIT_PROP_THRESHOLD,
      MAINNET_INIT_VOTE_QUORUM,
      MAINNET_PROTOCOL_TOKEN,
      _timelockController
    );

    // set odGovernor as PROPOSER_ROLE and EXECUTOR_ROLE
    _timelockController.grantRole(_timelockController.PROPOSER_ROLE(), address(_odGovernor));
    _timelockController.grantRole(_timelockController.EXECUTOR_ROLE(), address(_odGovernor));

    // revoke old odGovernor and devTeam from PROPOSER_ROLE and EXECUTOR_ROLE
    address oldGovernor = 0xb7D1793425494e4C4133cF947C0992DC85F2948E;
    _timelockController.revokeRole(_timelockController.PROPOSER_ROLE(), oldGovernor);
    _timelockController.revokeRole(_timelockController.EXECUTOR_ROLE(), oldGovernor);

    address oldDevTeam = 0xA0313248556DeA42fd17B345817Dd5DC5674c1E1;
    _timelockController.revokeRole(_timelockController.PROPOSER_ROLE(), oldDevTeam);
    _timelockController.revokeRole(_timelockController.EXECUTOR_ROLE(), oldDevTeam);

    _timelockController.grantRole(_timelockController.EXECUTOR_ROLE(), deployer);

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

    address deployer = vm.envAddress('ARB_SEPOLIA_DEPLOYER_ADDR');

    // empty address array for Proposers and Executors (ODGovernor will assume these roles)
    address[] memory members = new address[](0);

    _timelockController = new TimelockController(SEPOLIA_MIN_DELAY, members, members, deployer);

    _odGovernor = new ODGovernor(
      TEST_INIT_VOTING_DELAY,
      TEST_INIT_VOTING_PERIOD,
      TEST_INIT_PROP_THRESHOLD,
      TEST_INIT_VOTE_QUORUM,
      SEPOLIA_PROTOCOL_TOKEN,
      _timelockController
    );

    // set odGovernor as PROPOSER_ROLE and EXECUTOR_ROLE
    _timelockController.grantRole(_timelockController.PROPOSER_ROLE(), address(_odGovernor));
    _timelockController.grantRole(_timelockController.EXECUTOR_ROLE(), address(_odGovernor));

    /**
     * @dev this is now being proposed and executed by the DAO (deployer will keep admin role until DAO revokes it)
     *
     * revoke deployer from TIMELOCK_ADMIN_ROLE
     *   _timelockController.renounceRole(_timelockController.TIMELOCK_ADMIN_ROLE(), deployer);
     */
    vm.stopBroadcast();
  }
}
