// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/console2.sol';
import {Script} from 'forge-std/Script.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

/// @title ProposeAddCollateral Script
/// @author OpenDollar
/// @notice Script to propose adding a new collateral type to the system via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev The script will execute the proposal to deploy a new CollateralJoin and CollateralAuctionHouse
/// @dev To run: export FOUNDRY_PROFILE=governance && forge script script/gov/AddCollateralAction/ExecuteAddCollateral.s.sol in the root of the repo
contract ExecuteAddCollateral is Script {
  function run() public {
    /// REQUIRED ENV VARS ///
    // The address of the ODGovernor contract
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');

    // The path to the JSON file output by ProposeAddCollateral.s.sol
    string memory jsonFilePath = vm.envString('JSON_FILE_PATH');
    /// END REQUIRED ENV VARS ///

    // Expected JSON input:
    // {
    //   "addCollateralCalldatas": bytes[],
    //   "addCollateralDescription": string,
    //   "addCollateralDescriptionHash": bytes32,
    //   "addCollateralTargets": address[],
    //   "addCollateralValues": uint256[]
    // }
    string memory jsonFile = vm.readFile(jsonFilePath);

    string memory description = vm.parseJsonString(jsonFile, '.addCollateralDescription');
    console2.log(description);

    // Parse the JSON arguments from the output of ProposeAddCollateral.s.sol
    address[] memory targets = vm.parseJsonAddressArray(jsonFile, '.addCollateralTargets');
    uint256[] memory values = vm.parseJsonUintArray(jsonFile, '.addCollateralValues');
    bytes[] memory calldatas = vm.parseJsonBytesArray(jsonFile, '.addCollateralCalldatas');
    bytes32 descriptionHash = vm.parseJsonBytes32(jsonFile, '.addCollateralDescriptionHash');

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // execute proposal
    ODGovernor(payable(governanceAddress)).execute(targets, values, calldatas, descriptionHash);

    vm.stopBroadcast();
  }
}
