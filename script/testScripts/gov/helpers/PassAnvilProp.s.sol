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
    console2.log('Voting Delay:', gov.votingDelay());
    console2.log('Voting Period:', gov.votingPeriod());
    console2.log('Voting weight: ', IVotes(address(protocolToken)).getVotes(proposer));

    propState = gov.state(proposalId);
        (uint256 id,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool canceled,
            bool executed) = gov.proposals(proposalId);
            console2.log("FOR VOTES: ", forVotes);
            console2.log("AGAINST VOTES: ", againstVotes);
            console2.log("ABSTAIN VOTES: ", abstainVotes);
    console2.log(uint8(propState));
    if (propState == IGovernor.ProposalState.Active) {
      console2.log('Casting Vote...', block.number);
      gov.castVote(proposalId, 1);

      vm.roll(block.number + 16);
      vm.warp(block.timestamp + 300 seconds);

      propState = gov.state(proposalId);
      console2.log("PROP STATE: ", uint8(propState));
      if (propState == IGovernor.ProposalState.Succeeded) {
        console2.log('Proposal Passed');
      } else if (propState == IGovernor.ProposalState.Active) {
        console2.log('Proposal still active.');
      } else {
        console2.log('failed to pass proposal');
      }
    } else {
      console2.log('Vote not active! use anvil_mine 2 to mine 2 blocks and start voting.');
    }
  }

  function _delegateAndVote() internal {}
  function _passVote() internal {}
}
