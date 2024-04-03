// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

/// @title ModifyParameters Script
/// @author OpenDollar
/// @notice Script to modify parameters of any contract that inherits the "Modifiable.sol" contract
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev The script will propose modifying any paramters in a modifiable contract
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/ModifyParametersAction/ProposeModifyParameters.s.sol

contract ModifyParameters is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    // address of the governance contract
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    // address of the contract that you desire to modify the parameters of
    address targetContract = vm.envAddress('TARGET_CONTRACT');

    // get the desired parameter bytes32 with: cast format-bytes32-string <parameters string>

    // the encoded bytes of the desired parameter change e.g. the output of (cast calldata "modifyParameters(bytes32,bytes memory)" 0x676c6f62616c446562744365696c696e67000000000000000000000000000000 1000000000000000000000)
    bytes memory data = vm.envBytes('DESIRED_MODIFICATION');
    /// END REQUIRED ENV VARS ///

    ODGovernor gov = ODGovernor(payable(governanceAddress));

    address[] memory targets = new address[](1);
    {
      targets[0] = targetContract;
    }

    // No values needed
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
    }

    // bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = data;

    string memory description = 'Update Modifiable Param';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to modify parameters
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      // Build the JSON output
      string memory objectKey = 'MODIFY_PARAMETERS_KEY';
      vm.serializeBytes(objectKey, 'modifyParameters', _data);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-modify-parameters-proposal.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
    //   "blockDelay": uint8,
    //   "calldatas": bytes[],
    //   "targets": address[],
    //   "values": uint256[]
    //   "description": string,
    //   "descriptionHash": bytes32,
    // }

    vm.stopBroadcast();
  }
}
