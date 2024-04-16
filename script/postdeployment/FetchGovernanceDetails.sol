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
    bool governorIsAdmin = timelockController.hasRole(bytes32('TIMELOCK_ADMIN_ROLE'), address(governor));
    bool deployerIsAdmin =
      timelockController.hasRole(bytes32('TIMELOCK_ADMIN_ROLE'), 0xA0313248556DeA42fd17B345817Dd5DC5674c1E1);

    console2.log('TimelockController: minDelay: ', minDelay);
    console2.log('TimelockController: admin role goveror: ', governorIsAdmin);
    console2.log('TimelockController: admin role deployer: ', deployerIsAdmin);

    //  = governor.params();
  }
}
