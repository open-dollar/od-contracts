// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {SepoliaContracts} from '@script/SepoliaContracts.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';

// BROADCAST
// source .env && forge script DeployGovernor --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// source .env && forge script DeployGovernor --with-gas-price 2000000000 -vvvvv --chain-id 461614 --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --verifier-url $SEPOLIA_API --etherscan-api-key $ARB_ETHERSCAN_API_KEY --watch

// source .env && forge verify-contract 0xDb21D9e5616AEc3fA365879eCf3A5765C96bb62b ODGovernor --chain-id 461614 --watch --etherscan-api-key MQNZSPKCBZ9R4JEAW7FFFJ43DY9IVTAE7D

// SIMULATE
// source .env && forge script DeployGovernor --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployGovernor is SepoliaContracts, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    address[] memory members = new address[](3);
    members[0] = H;
    members[1] = J;
    members[2] = P;

    TimelockController timelockController = new TimelockController(1 minutes, members, members, address(0));

    new ODGovernor(
      TEST_INIT_VOTING_DELAY,
      TEST_INIT_VOTING_PERIOD,
      TEST_INIT_PROP_THRESHOLD,
      SEPOLIA_PROTOCOL_TOKEN,
      timelockController
    );
    vm.stopBroadcast();
  }
}
