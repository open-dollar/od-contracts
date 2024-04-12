// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {IGovernorTimelock, IGovernor} from '@openzeppelin/governance/extensions/IGovernorTimelock.sol';
import {ODTest, stdStorage, StdStorage} from '@test/utils/ODTest.t.sol';
import {MintableVoteERC20} from '@contracts/for-test/MintableVoteERC20.sol';

abstract contract Base is ODTest {
  using stdStorage for StdStorage;

  ODGovernor public odGovernor;
  address public deployer = newAddress();
  address public proposer = newAddress();
  address public executor = newAddress();
  address public alice = newAddress();
  address public bob = newAddress();
  MintableVoteERC20 public token;
  TimelockController timelock;

  string public constant proposal_description = 'Proposal #1: Mock Proposal';
  bytes32 public constant proposal_hash = keccak256(bytes(proposal_description));

  // variables for governor configuration
  uint256 initialVotingDelay = 1;
  uint256 initialVotingPeriod = 1000;
  uint256 initialProposalThreshold = 1;
  uint256 initialVoteQuorum = 3; // 3 / 1000 = 0.3% quorum

  function setUp() public virtual {
    vm.startPrank(deployer);

    // token with voting capabilities
    token = new MintableVoteERC20('Open Dollar Governance', 'ODG', 18);

    address[] memory proposers = new address[](1);
    proposers[0] = alice;
    address[] memory executors = new address[](1);
    executors[0] = alice;

    timelock = new TimelockController(1, proposers, executors, deployer);

    // initialize a new ODGovernor instance
    odGovernor = new ODGovernor(
      initialVotingDelay, initialVotingPeriod, initialProposalThreshold, initialVoteQuorum, address(token), timelock
    );
    timelock.grantRole(timelock.EXECUTOR_ROLE(), address(odGovernor));
    timelock.grantRole(timelock.PROPOSER_ROLE(), address(odGovernor));
    vm.stopPrank();
  }
}

contract Unit_ODGovernorTest is Base {
  function test_ODGovernor_Setup() public {
    assertEq(address(odGovernor.token()), address(token));
    assertEq(address(odGovernor.timelock()), address(timelock));
    assertEq(odGovernor.votingDelay(), initialVotingDelay);
    assertEq(odGovernor.votingPeriod(), initialVotingPeriod);
    assertEq(odGovernor.proposalThreshold(), initialProposalThreshold);
  }

  function test_ODGovernor_Quorum() public {
    // setup scenario: Alice and Bob have tokens
    token.mint(alice, 10 ether);
    token.mint(bob, 20 ether);
    vm.roll(100); // move to block number to 100
    assertEq(odGovernor.quorum(10), 0.09 ether); // 30 ether (totalSupply) * 0.3 ether (0.3% quorum) = 0.09 ether
  }

  function test_ODGovernor_SupportsInterface() public {
    bytes4 interfaceId = type(IGovernorTimelock).interfaceId;
    assertTrue(odGovernor.supportsInterface(interfaceId));
  }

  function test_ODGovernor_Votes() public {
    // setup: Alice receives tokens and delegates to herself
    token.mint(alice, 100 ether);
    vm.prank(alice);
    token.delegate(alice);
    vm.roll(11); // move to block number to 11

    uint256 getVotes = odGovernor.getVotes(alice, 10);
    uint256 numCheckpoints = token.numCheckpoints(alice);
    assertEq(getVotes, 100 ether);
    assertEq(numCheckpoints, 1);
  }

  function test_ODGovernor_Propose() public {
    // setup: Alice receives tokens and delegates to herself
    __mintAndDelegate(alice, 100 ether);
    vm.roll(100); // move to block number to 100
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = __createProposalArgs();
    vm.startPrank(alice);
    uint256 propId = odGovernor.propose(targets, values, calldatas, proposal_description);
    vm.roll(1000); // move to block number to some point inside the voting window

    uint256 proposalState = uint256(odGovernor.state(propId));
    assertEq(proposalState, uint256(IGovernor.ProposalState.Active));
  }

  function test_ODGovernor_Propose_and_Cancel() public {
    // setup: Alice receives tokens and delegates to herself
    __mintAndDelegate(alice, 100 ether);
    vm.roll(100); // move to block number to 100
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = __createProposalArgs();
    vm.startPrank(alice);
    uint256 propId = odGovernor.propose(targets, values, calldatas, proposal_description);
    vm.roll(1000); // move to block number to some point inside the voting window

    // cancel the proposal
    odGovernor.cancel(propId);
    uint256 proposalState = uint256(odGovernor.state(propId));
    assertEq(proposalState, uint256(IGovernor.ProposalState.Canceled));
  }

  function test_ODGovernor_Propose_and_CancelExtendedArguments() public {
    // setup: Alice receives tokens and delegates to herself
    __mintAndDelegate(alice, 100 ether);
    vm.roll(100); // move to block number to 100
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = __createProposalArgs();
    vm.startPrank(alice);
    uint256 propId = odGovernor.propose(targets, values, calldatas, proposal_description);
    vm.roll(1000); // move to block number to some point inside the voting window

    odGovernor.cancel(targets, values, calldatas, proposal_hash);
    uint256 proposalState = uint256(odGovernor.state(propId));
    assertEq(proposalState, uint256(IGovernor.ProposalState.Canceled));
  }

  function test_ODGovernor_Propsose_and_Execute() public {
    uint256 bobBalanceBeforeExecute = token.balanceOf(bob);
    uint256 blockTime = block.timestamp;
    uint256 blockNumber = block.number;

    // setup: Alice receives tokens and delegates to herself
    __mintAndDelegate(alice, 100 ether);
    vm.roll(100); // move to block number to 100

    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = __createProposalArgs();

    vm.startPrank(alice);
    uint256 propId = odGovernor.propose(targets, values, calldatas, proposal_description);
    vm.roll(blockNumber + 1000); // move to block number to some point inside the voting window

    odGovernor.castVote(propId, 1);
    vm.roll(blockNumber + 2002); // move to block number to some point inside the execution window

    odGovernor.queue(targets, values, calldatas, proposal_hash);
    vm.warp(blockTime + 1);

    // execute proposal
    vm.startPrank(executor);
    odGovernor.execute(propId);

    uint256 proposalState = uint256(odGovernor.state(propId));
    assertEq(proposalState, uint256(IGovernor.ProposalState.Executed));
    // execution should have minted 100 tokens to bob
    assertEq(token.balanceOf(bob), bobBalanceBeforeExecute + 100 ether);
  }

  // helpers
  function __createProposalArgs()
    public
    view
    returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
  {
    calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSignature('mint(address,uint256)', bob, 100 ether);
    targets = new address[](1);
    targets[0] = address(token);
    values = new uint256[](1);
    values[0] = 0;
  }

  function __mintAndDelegate(address _account, uint256 _amount) public {
    token.mint(_account, _amount);
    vm.startPrank(_account);
    token.delegate(_account);
    vm.stopPrank();
  }
}
