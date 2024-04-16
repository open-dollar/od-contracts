// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';
import {ForkManagement} from '@script/testScripts/gov/helpers/ForkManagement.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

contract Proposer is Script, ForkManagement {
  using stdJson for string;

  ODGovernor public governor;
  uint256[] public values;
  address[] public targets;
  bytes[] public calldatas;
  string public description;
  bytes32 public descriptionHash;
  uint256 public proposalId;

  function _loadBaseData(string memory json) internal virtual {
    values = json.readUintArray(string(abi.encodePacked('.values')));
    targets = json.readAddressArray(string(abi.encodePacked('.targets')));
    calldatas = json.readBytesArray(string(abi.encodePacked('.calldatas')));
    description = json.readString(string(abi.encodePacked('.description')));
    descriptionHash = json.readBytes32(string(abi.encodePacked('.descriptionHash')));
    proposalId = json.readUint(string(abi.encodePacked('.proposalId')));
    governor = ODGovernor(payable(json.readAddress(string(abi.encodePacked(('.odGovernor'))))));
  }

  function run(string memory _filePath) public {
    _loadJson(_filePath);
    _checkNetworkParams();
    _loadBaseData(json);
    _loadPrivateKeys();

    vm.startBroadcast(privateKey);
    require(_verifyProposal(), 'proposal not verifiable');
    console2.log('Proposal verified.  Proposing...');
    _propose();
    vm.stopBroadcast();
  }

  function _propose() internal virtual {
    uint256 newProposalId = governor.propose(targets, values, calldatas, description);
    // Verify the proposalId is expected
    assert(proposalId == newProposalId);
  }

  function _verifyProposal() internal view returns (bool _verified) {
    require(
      address(governor) != address(0) && values.length > 0 && values.length == targets.length
        && targets.length == calldatas.length,
      'params not set'
    );
    
    uint256 newProposalId = governor.hashProposal(targets, values, calldatas, descriptionHash);
    if (newProposalId == proposalId) {
      _verified = true;
    }
    console2.log('Proposal ID: ', proposalId);
    console2.log(description);
  }
}
