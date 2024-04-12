// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import 'forge-std/console2.sol';
import 'forge-std/Script.sol';
import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {ForkManagement} from '@script/testScripts/gov/helpers/ForkManagement.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

/// @title ExecuteProposal Script
/// @author OpenDollar
/// @notice Script to execute a proposal given a JSON file
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev The script will execute the proposal to set the NFT Renderer on Vault721
/// @dev To run: export FOUNDRY_PROFILE=governance && forge script script/testScripts/gov/UpdateNFTRendererAction/ExecuteUpdateNFTRenderer.s.sol in the root of the repo
contract ExecuteUpdateProposal is Script, ForkManagement {
  using stdJson for string;

  ODGovernor public governor;
  uint256[] public values;
  address[] targets;
  bytes[] public calldatas;
  string public description;
  bytes32 public descriptionHash;
  uint256 proposalId;

  function run(string memory _filePath) public {
    _loadJson(_filePath);
    _checkNetworkParams();
    _loadPrivateKeys();
    _loadBaseData(json);
    _executeProposal();
  }

  function _loadBaseData(string memory json) internal virtual {
    values = json.readUintArray(string(abi.encodePacked('.values')));
    targets = json.readAddressArray(string(abi.encodePacked('.targets')));
    calldatas = json.readBytesArray(string(abi.encodePacked('.calldatas')));
    description = json.readString(string(abi.encodePacked('.description')));
    descriptionHash = json.readBytes32(string(abi.encodePacked('.descriptionHash')));
    proposalId = json.readUint(string(abi.encodePacked('.proposalId')));
    governor = ODGovernor(payable(json.readAddress(string(abi.encodePacked(('.odGovernor'))))));
  }

  function _executeProposal() internal {
    vm.startBroadcast(privateKey);

    // execute proposal
    governor.execute(targets, values, calldatas, descriptionHash);

    vm.stopBroadcast();
  }
}
