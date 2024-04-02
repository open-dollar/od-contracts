// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

/// @title UpdateBlockDelay Script
/// @author OpenDollar
/// @notice Script to update the block delay via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev The script will propose setting the block delay value on Vault721
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/UpdateBlockDelayAction/ProposeUpdateBlockDelay.s.sol

contract UpdateBlockDelay is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    address vault721 = vm.envAddress('VAULT_721_ADDRESS');
    uint256 blockDelay = vm.envUint('BLOCK_DELAY');
    /// END REQUIRED ENV VARS ///

    ODGovernor gov = ODGovernor(payable(governanceAddress));

    address[] memory targets = new address[](1);
    {
      targets[0] = vault721;
    }

    // No values needed
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
    }

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSelector(IVault721.updateBlockDelay.selector, blockDelay);

    string memory description = 'Update Block Delay';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to update the block delay
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      // Build the JSON output
      string memory objectKey = 'UPDATE_BLOCK_DELAY_KEY';
      vm.serializeUint(objectKey, 'blockDelay', blockDelay);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-update-block-delay-proposal.json'));
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
