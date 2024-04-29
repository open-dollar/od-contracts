// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/gov/helpers/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {Generator} from '@script/gov/Generator.s.sol';
import 'forge-std/StdJson.sol';

contract GenerateUpdateDelayProposal is Generator, JSONScript {
  using stdJson for string;

  uint256 internal _newDelay;
  address internal _timelockController;
  address internal _odGovernor;
  string internal _description;

  function _loadBaseData(string memory json) internal override {
    _description = json.readString(string(abi.encodePacked('.description')));
    _newDelay = json.readUint(string(abi.encodePacked(('.newDelay'))));
    _timelockController = json.readAddress(string(abi.encodePacked('.TimelockController_Address')));
    _odGovernor = json.readAddress(string(abi.encodePacked('.ODGovernor_Address:')));
  }

  function _generateProposal() internal override {
    ODGovernor gov = ODGovernor(payable(_odGovernor));
    address[] memory targets = new address[](1);
    {
      targets[0] = _timelockController;
    }
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
    }
    bytes[] memory calldatas = new bytes[](1);
    {
      calldatas[0] = abi.encodeWithSelector(TimelockController.updateDelay.selector, _newDelay);
    }

    bytes32 descriptionHash = keccak256(bytes(_description));

    vm.startBroadcast(_privateKey);

    uint256 proposalId = gov.hashProposal(targets, values, calldatas, descriptionHash);

    // Propose the action to add the collateral type

    string memory stringProposalId = vm.toString(proposalId / 10 ** 69);

    {
      string memory objectKey = 'SCHEDULE-TIMELOCK-OBJECT';
      // Build the JSON output
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, _description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', _network, '/', stringProposalId, '-updateTimeDelay.json'));
    }

    vm.stopBroadcast();
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}
