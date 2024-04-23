// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Generator} from '@script/testScripts/gov/Generator.s.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
import 'forge-std/StdJson.sol';

// Mock contract for NitroPool that will be used in the script. This is used to be very clear about what we are proposing.
interface NitroPool {
  function addRewards(uint256 amountToken1, uint256 amountToken2) external;
}

/// @title ProposeAddRewardsToNitroPool Script
/// @author OpenDollar
/// @notice Script to propose adding rewards to NitroPool via ODGovernance
/// @dev This script is used to propose adding rewards to NitroPool, we first approve ERC20 to NitroPool and then call addRewards
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/AddRewardsToNitroPool/ProposeAddRewardsToNitroPool.s.sol
contract GenerateAddNitroRewardsProposal is Generator, JSONScript {
  using stdJson for string;

  string public description;
  address public governanceAddress;
  address public nitroPoolAddress;
  address[] public rewardTokens;
  uint256[] public rewardAmounts;

  function _loadBaseData(string memory json) internal override {
    governanceAddress = json.readAddress(string(abi.encodePacked('.ODGovernor_Address:')));
    description = json.readString(string(abi.encodePacked('.description')));
    nitroPoolAddress = json.readAddress(string(abi.encodePacked('.nitroPool')));
    uint256 len = json.readUint(string(abi.encodePacked('.arrayLength')));

    for (uint256 i; i < len; i++) {
      string memory index = Strings.toString(i);
      address token = json.readAddress(string(abi.encodePacked('.objectArray[', index, '].rewardToken')));
      uint256 amount = json.readUint(string(abi.encodePacked('.objectArray[', index, '].rewardAmount')));
      rewardTokens.push(token);
      rewardAmounts.push(amount);
    }
  }

  function _generateProposal() internal override {
    ODGovernor gov = ODGovernor(payable(governanceAddress));

    uint256 len = rewardTokens.length;
    require(len == rewardAmounts.length, 'NITRO PROPOSAL: mismatched reward array lengths');

    address[] memory targets = new address[](len + 1);
    uint256[] memory values = new uint256[](len + 1);
    bytes[] memory calldatas = new bytes[](len + 1);

    {
      for (uint256 i = 0; i < len; i++) {
        // approve nitro pool for target token's reward amount
        calldatas[i] = abi.encodeWithSelector(IERC20.approve.selector, nitroPoolAddress, rewardAmounts[i]);
        targets[i] = rewardTokens[i];
        values[i] = 0; // value is always 0
      }

      targets[len] = nitroPoolAddress;
      values[len] = 0;

      // add addRewards in last empty calldatas spot
      uint256 rewardAmount2 = len == 2 ? rewardAmounts[1] : 0;
      calldatas[len] = abi.encodeWithSelector(NitroPool.addRewards.selector, rewardAmounts[0], rewardAmount2);
    }
    // Get the description and descriptionHash
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(_privateKey);

    // Propose the action to add rewards to NitroPool
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId / 10 ** 69);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));
    {
      // Build the JSON output
      string memory objectKey = 'PROPOSE_ADD_NITROPOOL_REWARDS_KEY';
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(
        jsonOutput, string.concat('./gov-output/', _network, '/', stringProposalId, '-add-nitro-rewards.json')
      );
    }

    vm.stopBroadcast();
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}
