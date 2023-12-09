// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';

contract JSONScript is Script {
  function _buildProposalParamsJSON(
    uint256 proposalId,
    string memory objectKey,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    bytes32 descriptionHash
  ) internal returns (string memory jsonOutput) {
    vm.serializeUint(objectKey, 'proposalId', proposalId);
    vm.serializeAddress(objectKey, 'targets', targets);
    vm.serializeUint(objectKey, 'values', values);
    vm.serializeBytes(objectKey, 'calldatas', calldatas);
    vm.serializeString(objectKey, 'description', description);
    jsonOutput = vm.serializeBytes32(objectKey, 'descriptionHash', descriptionHash);
  }

  function _parseExecutionParamsJSON(string memory jsonFile)
    internal
    returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
  {
    targets = vm.parseJsonAddressArray(jsonFile, '.targets');
    values = vm.parseJsonUintArray(jsonFile, '.values');
    calldatas = vm.parseJsonBytesArray(jsonFile, '.calldatas');
    descriptionHash = vm.parseJsonBytes32(jsonFile, '.descriptionHash');
  }

  function _parseProposalId(string memory jsonFile) internal returns (uint256 proposalId) {
    proposalId = vm.parseJsonUint(jsonFile, '.proposalId');
  }
}
