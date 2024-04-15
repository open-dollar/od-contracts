// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Generator} from '@script/testScripts/gov/Generator.s.sol';
import 'forge-std/StdJson.sol';

/// @title ProposeAddCollateral Script
/// @author OpenDollar
/// @notice Script to propose ERC20 token to a specific account via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev This script is used to propose transfer from the governance contract to a specific account
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/ERC20TransferAction/ProposeERC20Transfer.s.sol
contract GenerateERC20TransferProposal is Generator, JSONScript {
  using stdJson for string;

  string public objectKey = 'PROPOSE_ERC20_TRANSFER_KEY';
  address public governanceAddress;
  address public ERC20TokenAddress;
  address public receiverAddress;
  address public fromAddress;
  uint256 public amountToTransfer;

  function _loadBaseData(string memory json) internal override {
    governanceAddress = json.readAddress(string(abi.encodePacked('.odGovernor')));
    ERC20TokenAddress = json.readAddress(string(abi.encodePacked('.erc20Token')));
    receiverAddress = json.readAddress(string(abi.encodePacked('.transferTo')));
    fromAddress = json.readAddress(string(abi.encodePacked('.transferFrom')));
    amountToTransfer = json.readUint('.amount');
  }

  function _generateProposal() internal override {
    ODGovernor gov = ODGovernor(payable(governanceAddress));
    address[] memory targets = new address[](1);
    {
      targets[0] = ERC20TokenAddress;
    }
    // No values needed
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
    }

    // Encode the calldata
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSelector(IERC20.transferFrom.selector, fromAddress, receiverAddress, amountToTransfer);

    // Get the description and descriptionHash
    string memory description = 'Transfer ERC20 tokens to receiver';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(privateKey);

    // Propose the action to add transfer the ERC20 token to the receiver
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId / 10 ** 69);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', network, '/', stringProposalId, '-transfer-erc20.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
    //   "tokenAddress": string,
    //   "fromAddress": string,
    //   "toAddress": string,
    //   "amountToTransferInWei": string,
    //   "targets": address[],
    //   "values": uint256[]
    //   "calldatas": bytes[],
    //   "description": string,
    //   "descriptionHash": bytes32,
    // }

    vm.stopBroadcast();
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}
