// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {ForkManagement} from '@script/testScripts/gov/helpers/ForkManagement.s.sol';
import 'forge-std/Script.sol';

/// @title QueueProposal Script
/// @author OpenDollar
/// @notice Script to queue an existing proposal to the system via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev NOTE Specify JSON_FILE_PATH in .env to select the proposal to queue
/// @dev There needs to be enough votes AND the time lock time must be passed as well

contract QueueProposal is ForkManagement, JSONScript {
  using stdJson for string;

  ODGovernor public governor;
  uint256[] public values;
  address[] public targets;
  bytes[] public calldatas;
  string public description;
  bytes32 public descriptionHash;
  uint256 public proposalId;

  function _loadBaseData(string memory json) internal virtual {
    values = json.readUintArray(string(abi.encodePacked('.values')));
    targets = json.readAddressArray(string(abi.encodePacked('.targets')));
    calldatas = json.readBytesArray(string(abi.encodePacked('.calldatas')));
    description = json.readString(string(abi.encodePacked('.description')));
    descriptionHash = json.readBytes32(string(abi.encodePacked('.descriptionHash')));
    proposalId = json.readUint(string(abi.encodePacked('.proposalId')));
    governor = ODGovernor(payable(json.readAddress(string(abi.encodePacked(('.odGovernor'))))));
  }

  function run(string memory _filePath) public {
    _loadJson(_filePath);
    _checkNetworkParams();
    _loadBaseData(json);
    _loadPrivateKeys();

    vm.startBroadcast(privateKey);
    _queueProposal();
    vm.stopBroadcast();
  }

  function _queueProposal() internal {
    uint256 queuedPropId = governor.queue(targets, values, calldatas, descriptionHash);
    assert(queuedPropId == proposalId);
  }
}
