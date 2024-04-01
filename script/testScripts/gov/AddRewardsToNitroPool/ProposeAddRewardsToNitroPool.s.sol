// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

// Mock contract for NitroPool that will be used in the script. This is used to be very clear about what we are proposing.
interface NitroPool {
  function addRewards(uint256 amountToken1, uint256 amountToken2) external;
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
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    address nitroPoolAddress = vm.envAddress('NITRO_POOL_ADDRESS');
    address rewardTokenAddress1 = vm.envAddress('REWARD_TOKEN_ADDRESS_1');
    address rewardTokenAddress2 = vm.envAddress('REWARD_TOKEN_ADDRESS_2');
    uint256 amountTokenReward1 = vm.envUint('AMOUNT_TOKEN_REWARD_1');
    uint256 amountTokenReward2 = vm.envUint('AMOUNT_TOKEN_REWARD_2');

    /// END REQUIRED ENV VARS ///

    ODGovernor gov = ODGovernor(payable(governanceAddress));
    address[] memory targets = new address[](1);
    {
      targets[0] = rewardTokenAddress1;
      targets[1] = rewardTokenAddress2;
      targets[2] = nitroPoolAddress;
    }
    // No values needed
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
      values[1] = 0;
      values[2] = 0;
    }

    // Get calldata for:
    //  - ERC20 Approve Nitro Pool (Token1)
    //  - ERC20 Approve Nitro Pool (Token2)
    //  - NitroPool.addRewards
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSelector(IERC20.approve.selector, nitroPoolAddress, amountTokenReward1);
    calldatas[1] = abi.encodeWithSelector(IERC20.approve.selector, nitroPoolAddress, amountTokenReward2);
    calldatas[2] = abi.encodeWithSelector(NitroPool.addRewards.selector, amountTokenReward1, amountTokenReward2);

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
      vm.serializeAddress(objectKey, 'rewardTokenAddress1', rewardTokenAddress1);
      vm.serializeAddress(objectKey, 'rewardTokenAddress2', rewardTokenAddress2);
      vm.serializeUint(objectKey, 'amountTokenReward1', amountTokenReward1);
      vm.serializeUint(objectKey, 'amountTokenReward2', amountTokenReward2);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-add-rewards-nitro-proposal.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
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
