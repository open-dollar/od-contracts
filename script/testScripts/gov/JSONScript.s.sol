// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Script} from 'forge-std/Script.sol';

contract JSONScript is Script {
  /// @notice Builds the JSON object for proposal parameters
  /// @param proposalId the proposal id
  /// @param objectKey  the object key to use for the JSON object
  /// @dev This must be called after serializing proposal specific details
  /// @return jsonOutput the string JSON output to be written to file
  function _buildProposalParamsJSON(
    uint256 proposalId,
    string memory objectKey,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    bytes32 descriptionHash
  ) internal returns (string memory jsonOutput) {
    _serializeCurrentJson(objectKey);
    vm.serializeUint(objectKey, 'proposalId', proposalId);
    vm.serializeAddress(objectKey, 'targets', targets);
    vm.serializeUint(objectKey, 'values', values);
    vm.serializeBytes(objectKey, 'calldatas', calldatas);
    vm.serializeString(objectKey, 'description', description);
    jsonOutput = vm.serializeBytes32(objectKey, 'descriptionHash', descriptionHash);
  }
  /// @notice override this in the generator script in order to include the input json file in the output file

  function _serializeCurrentJson(string memory objectKey) internal virtual returns (string memory _serializedInput) {}

  /// @notice Parses the params required for execution from a json file
  /// @param jsonFile the proposal to execute json output file
  /// @return targets the target contracts
  /// @return values the values to send in each calldata call
  /// @return calldatas the calldatas to execute
  /// @return descriptionHash the descriptionHash

  function _parseExecutionParamsJSON(string memory jsonFile)
    internal
    pure
    returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
  {
    targets = vm.parseJsonAddressArray(jsonFile, '.targets');
    values = vm.parseJsonUintArray(jsonFile, '.values');
    calldatas = vm.parseJsonBytesArray(jsonFile, '.calldatas');
    descriptionHash = vm.parseJsonBytes32(jsonFile, '.descriptionHash');
  }

  /// @notice Parses the params required for execution from a json file
  /// @return proposalId the proposal to execute json output file
  function _parseProposalId(string memory jsonFile) internal pure returns (uint256 proposalId) {
    proposalId = vm.parseJsonUint(jsonFile, '.proposalId');
  }
}
