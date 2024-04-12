// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

/// @title ProposeAddCollateral Script
/// @author OpenDollar
/// @notice Script to propose ERC20 token to a specific account via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev This script is used to propose transfer from the governance contract to a specific account
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/ERC20TransferAction/ProposeERC20Transfer.s.sol
contract ProposeERC20Transfer is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    address ERC20TokenAddress = vm.envAddress('ERC20_TRANSFER_TOKEN_ADDRESS');
    address receiverAddress = vm.envAddress('ERC20_TRANSFER_RECEIVER_ADDRESS');
    address fromAddress = vm.envAddress('ERC20_TRANSFER_FROM_ADDRESS');
    uint256 amountToTransfer = vm.envUint('ERC20_TRANSFER_AMOUNT');
    /// END REQUIRED ENV VARS ///

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

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to add transfer the ERC20 token to the receiver
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      string memory ERC20TokenAddressAsString = vm.toString(ERC20TokenAddress);
      string memory fromAddressAsString = vm.toString(fromAddress);
      string memory receiverAddressAsString = vm.toString(receiverAddress);

      // Build the JSON output
      string memory objectKey = 'PROPOSE_ERC20_TRANSFER_KEY';
      vm.serializeString(objectKey, 'tokenAddress', ERC20TokenAddressAsString);
      vm.serializeString(objectKey, 'fromAddress', fromAddressAsString);
      vm.serializeString(objectKey, 'toAddress', receiverAddressAsString);
      vm.serializeUint(objectKey, 'amountToTransferInWei', amountToTransfer);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-transfer-tokens-proposal.json'));
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
}
