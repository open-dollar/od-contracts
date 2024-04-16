// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {Generator} from '@script/testScripts/gov/Generator.s.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console2.sol';

contract GenerateUpdateDelayProposal is Generator, JSONScript {
  using stdJson for string;

  uint256 internal _newDelay;
  address internal _timelockController;
  address internal _governanceAddress;
  string internal _description;

  function _loadBaseData(string memory json) internal override {
    _description = json.readString(string(abi.encodePacked('.description')));
    _governanceAddress = json.readAddress(string(abi.encodePacked('.odGovernor')));
    _newDelay = json.readUint(string(abi.encodePacked(('.newDelay'))));
    _timelockController = json.readAddress(string(abi.encodePacked('.timelockController')));
  }

  function _generateProposal() internal override {
    ODGovernor gov = ODGovernor(payable(_governanceAddress));
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

    vm.startBroadcast(privateKey);

    // Propose the action to add the collateral type
    uint256 proposalId = gov.hashProposal(targets, values, calldatas, descriptionHash);
    string memory stringProposalId = vm.toString(proposalId / 10 ** 69);

    {
      string memory objectKey = 'UPDATE-TIMELOCK-OBJECT';
      // Build the JSON output
      string memory builtProp =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, _description, descriptionHash);
      vm.writeJson(builtProp, string.concat('./gov-output/', network, '/', stringProposalId, '-updateDelay.json'));
    }

    vm.stopBroadcast();
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}
