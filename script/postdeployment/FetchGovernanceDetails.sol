// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';
import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Common} from '@script/Common.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import 'forge-std/console2.sol';

// BROADCAST
// source .env && forge script FetchGovernanceParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script FetchGovernanceParams --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract FetchGovernanceParams is Common, SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    _fetchGovernanceParams();
    vm.stopBroadcast();
  }

  function _fetchGovernanceParams() internal view {
    uint256 minDelay = timelockController.getMinDelay();
    bool governorIsAdmin = timelockController.hasRole(timelockController.TIMELOCK_ADMIN_ROLE(), address(governor));
    bool deployerIsAdmin = timelockController.hasRole(timelockController.TIMELOCK_ADMIN_ROLE(), deployer);
    bool governorIsProposer = timelockController.hasRole(timelockController.PROPOSER_ROLE(), address(governor));
    bool deployerIsProposer = timelockController.hasRole(timelockController.PROPOSER_ROLE(), deployer);

    console2.log('Timelock Controller', address(timelockController));
    console2.log('minDelay: ', minDelay);
    console2.log('admin role goveror: ', governorIsAdmin);
    console2.log('admin role deployer: ', deployerIsAdmin);
    console2.log('Proposer role governor: ', governorIsProposer);
    console2.log('Proposer role deployer: ', deployerIsProposer);

    //  = governor.params();
  }
}
