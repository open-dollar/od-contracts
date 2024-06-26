// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/gov/helpers/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Generator} from '@script/gov/Generator.s.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
import {IChainlinkRelayerFactory} from '@interfaces/factories/IChainlinkRelayerFactory.sol';
import 'forge-std/StdJson.sol';

/// @title GenerateDeployChainlinkRelayersProposal Script
/// @author OpenDollar
/// @notice Script to generate a new chainlink relayer
/// @dev This script is used to create a proposal input to use the chainlinkRelayerFactory to deploy a new chainlink relayer
contract GenerateDeployChainlinkRelayersProposal is Generator, JSONScript {
  using stdJson for string;

  string public description;
  address public governanceAddress;
  address public chainlinkRelayerFactory;
  address[] public chainlinkFeed;
  uint256[] public oracleInterval;

  function _loadBaseData(string memory json) internal override {
    governanceAddress = json.readAddress(string(abi.encodePacked('.ODGovernor_Address:')));
    description = json.readString(string(abi.encodePacked('.description')));
    chainlinkRelayerFactory = json.readAddress(string(abi.encodePacked('.ChainlinkRelayerFactory_Address')));
    uint256 len = json.readUint(string(abi.encodePacked('.arrayLength')));

    for (uint256 i; i < len; i++) {
      string memory index = Strings.toString(i);
      address feed = json.readAddress(string(abi.encodePacked('.objectArray[', index, '].chainlinkFeed')));
      uint256 interval = json.readUint(string(abi.encodePacked('.objectArray[', index, '].oracleInterval')));
      chainlinkFeed.push(feed);
      oracleInterval.push(interval);
    }
  }

  function _generateProposal() internal override {
    ODGovernor gov = ODGovernor(payable(governanceAddress));

    uint256 len = chainlinkFeed.length;
    require(len == oracleInterval.length, 'CHAINLINK RELAYER: mismatched array lengths');

    address[] memory targets = new address[](len);
    uint256[] memory values = new uint256[](len);
    bytes[] memory calldatas = new bytes[](len);

    for (uint256 i = 0; i < len; i++) {
      // encode relayer factory function data
      calldatas[i] = abi.encodeWithSelector(
        IChainlinkRelayerFactory.deployChainlinkRelayer.selector, chainlinkFeed[i], oracleInterval[i]
      );
      targets[i] = chainlinkRelayerFactory;
      values[i] = 0; // value is always 0
    }

    // Get the description and descriptionHash
    bytes32 descriptionHash = keccak256(bytes(description));

    // Propose the action
    uint256 proposalId = gov.hashProposal(targets, values, calldatas, descriptionHash);
    string memory stringProposalId = vm.toString(proposalId / 10 ** 69);

    {
      // Build the JSON output
      string memory objectKey = 'PROPOSE_DEPLOY_CHAINLINK_RELAYER_KEY';
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(
        jsonOutput, string.concat('./gov-output/', _network, '/', stringProposalId, '-deploy-chainlink-relayer.json')
      );
    }
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}
