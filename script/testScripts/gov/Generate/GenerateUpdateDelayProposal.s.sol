// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {Generator} from '@script/testScripts/gov/Generator.s.sol';
import 'forge-std/StdJson.sol';

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
    // ODGovernor gov = ODGovernor(payable(_governanceAddress));
    TimelockController tlc = TimelockController(payable(_timelockController));
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

    // bytes32 descriptionHash = keccak256(bytes(_description));

    vm.startBroadcast(privateKey);
    bytes32 operationHash = tlc.hashOperation(targets[0], values[0], calldatas[0], bytes32(0), bytes32(0));

    tlc.schedule(targets[0], values[0], calldatas[0], bytes32(0), bytes32(0), 0);

    // Propose the action to add the collateral type

    string memory stringOperationHash = vm.toString(uint256(operationHash) / 10 ** 69);

    {
      string memory objectKey = 'SCHEDULE-TIMELOCK-OBJECT';
      // Build the JSON output
      _serializeCurrentJson(objectKey);
      vm.serializeAddress(objectKey, 'targets', targets);
      vm.serializeUint(objectKey, 'values', values);
      vm.serializeBytes(objectKey, 'calldatas', calldatas);
      string memory jsonOutput = vm.serializeBytes32(objectKey, 'operationHash', operationHash);
      vm.writeJson(
        jsonOutput, string.concat('./gov-output/', network, '/', stringOperationHash, '-updateTimeDelay.json')
      );
    }

    vm.stopBroadcast();
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}
