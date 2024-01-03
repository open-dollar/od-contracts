// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

/// @title ProposeUpdatePidController Script
/// @author OpenDollar
/// @notice Script to propose updating PID Controller params via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev This script is used to propose updating PID Controller params
/// @dev The script will update some PID Controller params
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script script/gov/UpdatePidControllerAction/ProposeUpdatePidController.s.sol
contract ProposeUpdatePidController is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    address pidControllerAddress = vm.envAddress('PID_CONTROLLER_ADDRESS');
    address seedProposer = vm.envAddress('SEED_PROPOSER');
    uint256 noiseBarrier = vm.envUint('NOISE_BARRIER');
    uint256 integralPeriodSize = vm.envUint('INTEGRAL_PERIOD_SIZE');
    uint256 feedbackOutputUpperBound = vm.envUint('FEEDBACK_OUTPUT_UPPER_BOUND');
    int256 feedbackOutputLowerBound = vm.envInt('FEEDBACK_OUTPUT_LOWER_BOUND');
    uint256 perSecondCumulativeLeak = vm.envUint('PER_SECOND_CUMULATIVE_LEAK');
    int256 kp = vm.envInt('KP');
    int256 ki = vm.envInt('KI');
    int256 priceDeviationCumulative = vm.envInt('PRICE_DEVIATION_CUMULATIVE');

    /// END REQUIRED ENV VARS ///

    ODGovernor gov = ODGovernor(payable(governanceAddress));

    address[] memory targets = new address[](1);
    {
      targets[0] = pidControllerAddress;
    }

    // No values needed
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
    }

    bytes[] memory calldatas = new bytes[](9);
    string memory sig = 'modifyParameters(bytes32,bytes)';
    calldatas[0] = abi.encodeWithSignature(sig, 'seedProposer', abi.encode(seedProposer));
    calldatas[1] = abi.encodeWithSignature(sig, 'noiseBarrier', abi.encode(noiseBarrier));
    calldatas[2] = abi.encodeWithSignature(sig, 'integralPeriodSize', abi.encode(integralPeriodSize));
    calldatas[3] = abi.encodeWithSignature(sig, 'feedbackOutputUpperBound', abi.encode(feedbackOutputUpperBound));
    calldatas[4] = abi.encodeWithSignature(sig, 'feedbackOutputLowerBound', abi.encode(feedbackOutputLowerBound));
    calldatas[5] = abi.encodeWithSignature(sig, 'perSecondCumulativeLeak', abi.encode(perSecondCumulativeLeak));
    calldatas[6] = abi.encodeWithSignature(sig, 'kp', abi.encode(kp));
    calldatas[7] = abi.encodeWithSignature(sig, 'ki', abi.encode(ki));
    calldatas[8] = abi.encodeWithSignature(sig, 'priceDeviationCumulative', abi.encode(priceDeviationCumulative));

    string memory description = 'Update PID Controller';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to add the collateral type
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      // Build the JSON output
      string memory objectKey = 'UPDATE_PID_CONTROLLER_KEY';
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-update-pid-controller-proposal.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
    //   "calldatas": bytes[],
    //   "targets": address[],
    //   "values": uint256[]
    //   "description": string,
    //   "descriptionHash": bytes32,
    // }

    vm.stopBroadcast();
  }
}
