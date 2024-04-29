// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {SepoliaContracts} from '@script/SepoliaContracts.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';

// BROADCAST
// source .env && forge script DeployGovernor --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployGovernor --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployGovernor is SepoliaContracts, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    new ODGovernor(
      SEPOLIA_INIT_VOTING_DELAY,
      SEPOLIA_INIT_VOTING_PERIOD,
      SEPOLIA_INIT_PROP_THRESHOLD,
      SEPOLIA_INIT_VOTE_QUORUM,
      SEPOLIA_PROTOCOL_TOKEN,
      TimelockController(payable(SEPOLIA_TIMELOCK_CONTROLLER))
    );
    vm.stopBroadcast();
  }
}
