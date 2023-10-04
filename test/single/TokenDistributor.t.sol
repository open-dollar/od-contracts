// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20VotesForTest} from '@test/mocks/ERC20VotesForTest.sol';
import {TokenDistributor} from '@contracts/tokens/TokenDistributor.sol';
import {MerkleTreeGenerator} from '@test/utils/MerkleTreeGenerator.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract SingleTokenDistributorTest is HaiTest {
  Hevm hevm;

  TokenDistributor tokenDistributor;
  ERC20VotesForTest token;
  MerkleTreeGenerator merkleTreeGenerator;
  bytes32[] merkleTree;
  bytes32[] leaves;

  bytes32 merkleRoot;

  address[] airdropRecipients;

  uint256[] airdropAmounts;

  uint256 airdropAmount = 100_000;
  uint256 totalClaimable = 500_000;
  uint256 claimPeriodStart = block.timestamp + 10 days;
  uint256 claimPeriodEnd = block.timestamp + 20 days;

  address deployer = label('deployer');

  address eve = label('eve');
  bytes32[] validEveProofs;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    airdropRecipients = new address[](5);
    airdropRecipients[0] = label('alice');
    airdropRecipients[1] = label('bob');
    airdropRecipients[2] = label('charlie');
    airdropRecipients[3] = label('david');
    airdropRecipients[4] = eve;

    airdropAmounts = new uint256[](5);
    airdropAmounts[0] = airdropAmount;
    airdropAmounts[1] = airdropAmount;
    airdropAmounts[2] = airdropAmount;
    airdropAmounts[3] = airdropAmount;
    airdropAmounts[4] = airdropAmount;

    for (uint256 i = 0; i < airdropRecipients.length; i++) {
      leaves.push(keccak256(bytes.concat(keccak256(abi.encode(airdropRecipients[i], airdropAmounts[i])))));
    }

    vm.prank(deployer);
    merkleTreeGenerator = new MerkleTreeGenerator();
    merkleTree = merkleTreeGenerator.generateMerkleTree(leaves);
    merkleRoot = merkleTree[0];

    vm.prank(deployer);
    token = new ERC20VotesForTest();

    vm.prank(deployer);
    tokenDistributor = new TokenDistributor(
            merkleRoot,
            token,
            totalClaimable,
            claimPeriodStart,
            claimPeriodEnd
        );

    vm.prank(deployer);
    token.mint(address(tokenDistributor), totalClaimable);

    uint256 _index = merkleTreeGenerator.getIndex(merkleTree, leaves[4]);
    validEveProofs = merkleTreeGenerator.getProof(merkleTree, _index);
  }

  function test_claim_votingPowerTransfers() public {
    // Check that eve has no voting power
    assertEq(0, token.getVotes(eve));

    vm.warp(claimPeriodStart);
    // Eve delegates to herself
    vm.prank(eve);
    token.delegate(eve);
    // Eve claims tokens
    vm.prank(eve);
    tokenDistributor.claim(validEveProofs, airdropAmount);

    // Assert that eve received the voting power
    assertEq(airdropAmount, token.getVotes(eve));
  }
}
