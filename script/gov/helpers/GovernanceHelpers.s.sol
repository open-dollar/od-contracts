// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//solhint-disable

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';
import {AnvilDeployment} from '@script/anvil/deployment/AnvilDeployment.t.sol';
import {ForkManagement} from '@script/gov/helpers/ForkManagement.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IGovernor} from '@openzeppelin/governance/IGovernor.sol';
import {IVotes} from '@openzeppelin/governance/utils/IVotes.sol';

contract GovernanceHelpers is Script, ForkManagement {
  using stdJson for string;

  IGovernor.ProposalState public propState;
  ODGovernor public gov;
  uint256[] public values;
  address[] public targets;
  bytes[] public calldatas;
  string public description;
  bytes32 public descriptionHash;
  uint256 public proposalId;
  address protocolToken;

  function _loadBaseData() internal virtual {
    values = json.readUintArray(string(abi.encodePacked('.values')));
    targets = json.readAddressArray(string(abi.encodePacked('.targets')));
    calldatas = json.readBytesArray(string(abi.encodePacked('.calldatas')));
    description = json.readString(string(abi.encodePacked('.description')));
    descriptionHash = json.readBytes32(string(abi.encodePacked('.descriptionHash')));
    proposalId = json.readUint(string(abi.encodePacked('.proposalId')));
    gov = ODGovernor(payable(json.readAddress(string(abi.encodePacked(('.ODGovernor_Address'))))));
    protocolToken = json.readAddress(string(abi.encodePacked('.ProtocolToken_Address')));
  }

  function run(string memory _filePath) public {
    _loadJson(_filePath);
    _checkNetworkParams();
    _loadPrivateKeys();
    _loadBaseData();

    vm.startBroadcast(_privateKey);
    _Vote();
  }

  function delegateTokens(string memory _filePath) public {
    _loadJson(_filePath);
    _checkNetworkParams();
    _loadPrivateKeys();
    protocolToken = json.readAddress(string(abi.encodePacked('.ProtocolToken_Address')));

    vm.startBroadcast(_privateKey);
    IVotes(protocolToken).delegate(proposer);
    uint256 voteWeight = IVotes(protocolToken).getVotes(proposer);
    console2.log('Current vote weight: ', voteWeight);
  }

  function _Vote() internal {
    console2.log('Voting Delay:', gov.votingDelay());
    console2.log('Voting Period:', gov.votingPeriod());
    console2.log('Voting weight: ', IVotes(address(protocolToken)).getVotes(proposer));

    propState = gov.state(proposalId);
    if (propState == IGovernor.ProposalState.Active) {
      console2.log('#######################################');
      console2.log('Casting Vote...');
      gov.castVote(proposalId, 1);

      _getPropInfo(proposalId);
      _logPropState(propState);
    } else {
      console2.log('#######################################');
      console2.log('Vote not active!');
      _logPropState(propState);
      _getPropInfo(proposalId);
    }
  }

  function _getPropInfo(uint256 propId) internal {
    (
      uint256 id,
      address proposer,
      ,
      uint256 startBlock,
      uint256 endBlock,
      uint256 forVotes,
      uint256 againstVotes,
      uint256 abstainVotes,
      ,
    ) = gov.proposals(propId);
    console2.log('PROPID: ', id);
    console2.log('PROPOSER: ', proposer);
    console2.log('START BLOCK: ', startBlock);
    console2.log('END BLOCK: ', endBlock);
    console2.log('FOR VOTES: ', forVotes);
    console2.log('AGAINST VOTES: ', againstVotes);
    console2.log('ABSTAIN VOTES: ', abstainVotes);
  }

  function _logPropState(IGovernor.ProposalState _state) internal {
    if (uint8(_state) == 0) {
      console2.log('Prop state: Pending');
    } else if (uint8(_state) == 1) {
      console2.log('Prop state: Active');
    } else if (uint8(_state) == 2) {
      console2.log('Prop state: Canceled');
    } else if (uint8(_state) == 3) {
      console2.log('Prop state: Defeated');
    } else if (uint8(_state) == 4) {
      console2.log('Prop state: Succeeded');
    } else if (uint8(_state) == 5) {
      console2.log('Prop state: Queued');
    } else if (uint8(_state) == 6) {
      console2.log('Prop state: Expired');
    } else if (uint8(_state) == 7) {
      console2.log('Prop state: Executed');
    }
  }
}
