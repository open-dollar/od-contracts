// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//solhint-disable

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';
import {AnvilDeployment} from '@script/anvil/deployment/AnvilDeployment.t.sol';
import {ForkManagement} from '@script/testScripts/gov/helpers/ForkManagement.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';
import {IVotes} from '@openzeppelin/governance/utils/IVotes.sol';

contract PassAnvilProp is Script, AnvilDeployment, ForkManagement {
  using stdJson for string;

  IGovernor.ProposalState public propState;
  ODGovernor public gov;
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
    gov = ODGovernor(payable(json.readAddress(string(abi.encodePacked(('.odGovernor'))))));
  }

  function run(string memory _filePath) public {
    _loadJson(_filePath);
    _checkNetworkParams();
    _loadPrivateKeys();
    _loadBaseData(json);

    vm.startBroadcast(_privateKey);

    console2.log('Delegating Token...');
    IVotes(address(protocolToken)).delegate(proposer);

    console2.log("IT'S A TIME WARP!!!");
    vm.roll(block.number + 2);
    vm.warp(block.timestamp + 30 seconds);
    propState = gov.state(proposalId);
    console2.log(uint8(propState));
    if (propState == IGovernor.ProposalState.Active) {
      console2.log('Casting Vote...');
      gov.castVote(proposalId, 1);

      console2.log("IT'S A TIME WARP!!!");
      vm.roll(block.number + 16);
      vm.warp(block.timestamp + 300 seconds);

      propState = gov.state(proposalId);
      if (propState == IGovernor.ProposalState.Succeeded) {
        console2.log('Proposal Passed');
      } else if (propState == IGovernor.ProposalState.Active) {
        console2.log('Proposal still active.');
      } else {
        console2.log('failed to pass proposal');
      }
    } else {
      console2.log('VOTE NOT ACTIVE!');
    }
  }

  function mintProtocolTokens() public {
    protocolToken.mint(msg.sender, 100 ether);
  }

  function _delegateAndVote() internal {}
  function _passVote() internal {}
}
