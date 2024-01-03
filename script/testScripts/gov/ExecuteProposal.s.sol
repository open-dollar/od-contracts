// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/console2.sol';
import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

/// @title ExecuteProposal Script
/// @author OpenDollar
/// @notice Script to execute a proposal given a JSON file
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev The script will execute the proposal to set the NFT Renderer on Vault721
/// @dev To run: export FOUNDRY_PROFILE=governance && forge script script/gov/UpdateNFTRendererAction/ExecuteUpdateNFTRenderer.s.sol in the root of the repo
contract ExecuteUpdateProposal is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    // The address of the ODGovernor contract
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');

    // The path to the JSON file for the desired proposal to execute
    string memory jsonFilePath = vm.envString('JSON_FILE_PATH');

    uint256 govPK = vm.envUint('GOV_EXECUTOR_PK');
    /// END REQUIRED ENV VARS ///

    // See Propose{GovAction}.s.sol to see the expected JSON input
    string memory jsonFile = vm.readFile(jsonFilePath);

    string memory description = vm.parseJsonString(jsonFile, '.description');
    console2.log(description);

    // Parse the JSON arguments from the output of Propose{GovAction}.s.sol
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) =
      _parseExecutionParamsJSON(jsonFile);

    vm.startBroadcast(govPK);

    // execute proposal
    ODGovernor(payable(governanceAddress)).execute(targets, values, calldatas, descriptionHash);

    vm.stopBroadcast();
  }
}
