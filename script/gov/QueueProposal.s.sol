// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

/// @title QueueProposal Script
/// @author OpenDollar
/// @notice Script to queue an existing proposal to the system via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev There needs to be enough votes AND the time lock time must be passed as well

contract QueueProposal is Script {
  function run() public {
    /// REQUIRED ENV VARS ///
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    uint256 propId = vm.envUint('PROPOSAL_ID');
    uint256 govPK = vm.envUint('GOV_EXECUTOR_PK');
    /// END REQUIRED ENV VARS ///

    ODGovernor gov = ODGovernor(payable(governanceAddress));

    vm.startBroadcast(govPK);

    gov.queue(propId);

    vm.stopBroadcast();

    IGovernor.ProposalState propState = gov.state(propId);
    assert(propState == IGovernor.ProposalState.Queued);
  }
}
