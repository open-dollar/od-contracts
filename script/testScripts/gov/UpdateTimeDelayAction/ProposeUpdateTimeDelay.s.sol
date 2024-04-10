// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

/// @title UpdateTimeDelay Script
/// @author OpenDollar
/// @notice Script to update the time delay via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev The script will propose setting the time delay value on Vault721
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/UpdateTimeDelayAction/ProposeUpdateTimeDelay.s.sol

contract UpdateTimeDelay is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    address vault721 = vm.envAddress('VAULT_721_ADDRESS');
    uint256 timeDelay = vm.envUint('TIME_DELAY');
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
    calldatas[0] = abi.encodeWithSelector(Modifiable.modifyParameters.selector, timeDelay);

    string memory description = 'Update Time Delay';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to add the collateral type
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      // Build the JSON output
      string memory objectKey = 'UPDATE_TIME_DELAY_KEY';
      vm.serializeUint(objectKey, 'timeDelay', timeDelay);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-update-time-delay-proposal.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
    //   "timeDelay": uint256,
    //   "calldatas": bytes[],
    //   "targets": address[],
    //   "values": uint256[]
    //   "description": string,
    //   "descriptionHash": bytes32,
    // }

    vm.stopBroadcast();
  }
}
