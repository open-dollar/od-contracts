// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

// Mock contract for NitroPool that will be used in the script. This is used to be very clear about what we are proposing.
interface NitroPool {
  function addRewards(uint256 amountToken1, uint256 amountToken2) external;
}

struct ProposalData {
  address governanceAddress;
  address nitroPoolAddress;
  address rewardTokenAddress1;
  address rewardTokenAddress2;
  uint256 amountTokenReward1;
  uint256 amountTokenReward2;
}

/// @title ProposeAddRewardsToNitroPool Script
/// @author OpenDollar
/// @notice Script to propose adding rewards to NitroPool via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev This script is used to propose adding rewards to NitroPool, we first approve ERC20 to NitroPool and then call addRewards
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/AddRewardsToNitroPool/ProposeAddRewardsToNitroPool.s.sol
contract ProposeAddRewardsToNitroPool is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///

    // using a struct so we don't get stack too deep errors
    ProposalData memory data = ProposalData({
      governanceAddress: vm.envAddress('GOVERNANCE_ADDRESS'),
      nitroPoolAddress: vm.envAddress('NITRO_POOL_ADDRESS'),
      rewardTokenAddress1: vm.envAddress('REWARD_TOKEN_ADDRESS_1'),
      rewardTokenAddress2: vm.envAddress('REWARD_TOKEN_ADDRESS_2'),
      amountTokenReward1: vm.envUint('AMOUNT_TOKEN_REWARD_1'),
      amountTokenReward2: vm.envUint('AMOUNT_TOKEN_REWARD_2')
    });

    /// END REQUIRED ENV VARS ///

    ODGovernor gov = ODGovernor(payable(data.governanceAddress));

    // we need to support the case where we only have one reward token, so we need to dynamically build the targets and calldatas and avoid approving 0 amounts
    // at most we will have 3 targets, 3 calldatas, value is always 0
    bytes[] memory tempCalldatas = new bytes[](3);
    address[] memory tempTargets = new address[](3);
    // count is used to keep track of the number of targets and calldatas
    uint256 count = 0;

    if (data.amountTokenReward1 > 0) {
      tempTargets[count] = data.rewardTokenAddress1;
      tempCalldatas[count] =
        abi.encodeWithSelector(IERC20.approve.selector, data.nitroPoolAddress, data.amountTokenReward1);
      count++;
    }

    if (data.amountTokenReward2 > 0) {
      tempTargets[count] = data.rewardTokenAddress2;
      tempCalldatas[count] =
        abi.encodeWithSelector(IERC20.approve.selector, data.nitroPoolAddress, data.amountTokenReward2);
      count++;
    }

    tempTargets[count] = data.nitroPoolAddress;
    tempCalldatas[count] =
      abi.encodeWithSelector(NitroPool.addRewards.selector, data.amountTokenReward1, data.amountTokenReward2);
    count++;

    address[] memory targets = new address[](count);
    uint256[] memory values = new uint256[](count);
    bytes[] memory calldatas = new bytes[](count);
    for (uint256 i = 0; i < count; i++) {
      calldatas[i] = tempCalldatas[i];
      targets[i] = tempTargets[i];
      values[i] = 0; // value is always 0
    }

    // Get the description and descriptionHash
    string memory description = 'Add rewards to NitroPool';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to add rewards to NitroPool
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));
    {
      // Build the JSON output
      string memory objectKey = 'PROPOSE_ADD_NITROPOOL_REWARDS_KEY';
      vm.serializeAddress(objectKey, 'nitroPoolAddress', data.nitroPoolAddress);
      vm.serializeAddress(objectKey, 'rewardTokenAddress1', data.rewardTokenAddress1);
      vm.serializeAddress(objectKey, 'rewardTokenAddress2', data.rewardTokenAddress2);
      vm.serializeUint(objectKey, 'amountTokenReward1', data.amountTokenReward1);
      vm.serializeUint(objectKey, 'amountTokenReward2', data.amountTokenReward2);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-add-rewards-nitro-proposal.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
    //   "nitroPoolAddress": string,
    //   "rewardTokenAddress1": string,
    //   "rewardTokenAddress2": string,
    //   "amountTokenReward1": string,
    //   "amountTokenReward1": bytes32,
    //   "targets": address[],
    //   "values": uint256[]
    //   "calldatas": bytes[],
    //   "description": string,
    //   "descriptionHash": bytes32,
    // }

    vm.stopBroadcast();
  }
}
