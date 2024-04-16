// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

/// @title QueueProposal Script
/// @author OpenDollar
/// @notice Script to queue an existing proposal to the system via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev NOTE Specify JSON_FILE_PATH in .env to select the proposal to queue
/// @dev There needs to be enough votes AND the time lock time must be passed as well

contract QueueProposal is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');

    // The path to the JSON file for the desired proposal to execute
    string memory jsonFilePath = vm.envString('JSON_FILE_PATH');

    uint256 govPK = vm.envUint('GOV_EXECUTOR_PK');
    /// END REQUIRED ENV VARS ///

    ODGovernor gov = ODGovernor(payable(governanceAddress));

    uint256 proposalId = _parseProposalId(jsonFilePath);

    vm.startBroadcast(govPK);

    gov.queue(proposalId);

    vm.stopBroadcast();

    IGovernor.ProposalState propState = gov.state(proposalId);
    assert(propState == IGovernor.ProposalState.Queued);
  }
}
