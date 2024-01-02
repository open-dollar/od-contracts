// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

/// @title ProposeUpdateNFTRenderer Script
/// @author OpenDollar
/// @notice Script to propose updating the NFT Renderer contract via ODGovernance
/// @dev NOTE This script requires the following env vars in the REQUIRED ENV VARS section below
/// @dev This script is used to propose updating the NFT Renderer contract on the Vault721 contract
/// @dev The script will deploy an NFT Renderer contract and propose setting the NFT Renderer on Vault721
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script script/gov/UpdateNFTRendererAction/ProposeUpdateNFTRenderer.s.sol
contract ProposeUpdateNFTRenderer is JSONScript {
  function run() public {
    /// REQUIRED ENV VARS ///
    address governanceAddress = vm.envAddress('GOVERNANCE_ADDRESS');
    address vault721 = vm.envAddress('VAULT_721_ADDRESS');
    address oracleRelayer = vm.envAddress('ORACLE_RELAYER_ADDRESS');
    address taxCollector = vm.envAddress('TAX_COLLECTOR_ADDRESS');
    address collateralJoinFactory = vm.envAddress('COLLATERAL_JOIN_FACTORY_ADDRESS');
    /// END REQUIRED ENV VARS ///

    NFTRenderer nftRenderer = new NFTRenderer(vault721, oracleRelayer, taxCollector, collateralJoinFactory);
    address nftRendererAddress = address(nftRenderer);
    ODGovernor gov = ODGovernor(payable(governanceAddress));

    address[] memory targets = new address[](1);
    {
      targets[0] = vault721;
    }

    // No values needed
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
    }

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSelector(
      IVault721.updateNftRenderer.selector, nftRendererAddress, oracleRelayer, taxCollector, collateralJoinFactory
    );

    string memory description = 'Update NFTRenderer';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to add the collateral type
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      // Build the JSON output
      string memory objectKey = 'UPDATE_NFT_RENDERER_KEY';
      vm.serializeAddress(objectKey, 'nftRendererAddress', nftRendererAddress);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-update-nft-renderer-proposal.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
    //   "nftRendererAddress": address,
    //   "calldatas": bytes[],
    //   "targets": address[],
    //   "values": uint256[]
    //   "description": string,
    //   "descriptionHash": bytes32,
    // }

    vm.stopBroadcast();
  }
}
