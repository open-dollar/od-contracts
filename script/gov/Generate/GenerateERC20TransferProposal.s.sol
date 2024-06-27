// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/gov/helpers/JSONScript.s.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Generator} from '@script/gov/Generator.s.sol';
import 'forge-std/StdJson.sol';

/// @title ProposeAddCollateral Script
/// @author OpenDollar
/// @notice Script to propose ERC20 token to a specific account via ODGovernance
/// @dev This script is used to propose transfer from the governance contract to a specific account
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/gov/ERC20TransferAction/ProposeERC20Transfer.s.sol
contract GenerateERC20TransferProposal is Generator, JSONScript {
  using stdJson for string;

  address public governanceAddress;
  string public description;
  address[] public ERC20TokenAddresses;
  address[] public receiverAddresses;
  uint256[] public amountsToTransfer;

  function _loadBaseData(string memory json) internal override {
    governanceAddress = json.readAddress(string(abi.encodePacked('.ODGovernor_Address:')));
    description = json.readString(string(abi.encodePacked('.description')));
    uint256 len = json.readUint(string(abi.encodePacked('.arrayLength')));

    for (uint256 i; i < len; i++) {
      string memory index = Strings.toString(i);
      address token = json.readAddress(string(abi.encodePacked('.objectArray[', index, '].erc20Token')));
      address transferTo = json.readAddress(string(abi.encodePacked('.objectArray[', index, '].transferTo')));
      uint256 amount = json.readUint(string(abi.encodePacked('.objectArray[', index, '].amount')));
      ERC20TokenAddresses.push(token);
      receiverAddresses.push(transferTo);
      amountsToTransfer.push(amount);
    }
  }

  function _generateProposal() internal override {
    ODGovernor gov = ODGovernor(payable(governanceAddress));
    uint256 len = ERC20TokenAddresses.length;
    require(len == receiverAddresses.length && len == amountsToTransfer.length, 'ERC20 TRANSFER: array length mismatch');

    address[] memory targets = new address[](len);
    uint256[] memory values = new uint256[](len);
    bytes[] memory calldatas = new bytes[](len);

    for (uint256 i; i < len; i++) {
      targets[i] = ERC20TokenAddresses[i];
      values[i] = 0;
      calldatas[i] = abi.encodeWithSelector(IERC20.transfer.selector, receiverAddresses[i], amountsToTransfer[i]);
    }

    // Get the descriptionHash
    bytes32 descriptionHash = keccak256(bytes(description));

    // Propose the action to add transfer the ERC20 token to the receiver
    uint256 proposalId = gov.hashProposal(targets, values, calldatas, descriptionHash);
    string memory stringProposalId = vm.toString(proposalId / 10 ** 69);

    {
      string memory objectKey = 'PROPOSE_ERC20_TRANSFER_KEY';
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', _network, '/transfer-erc20', stringProposalId, '.json'));
    }
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}
