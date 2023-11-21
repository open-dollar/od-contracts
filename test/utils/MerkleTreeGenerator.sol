// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * Test helper contract to generate Merkle trees and proofs.
 */
contract MerkleTreeGenerator {
  function generateMerkleTree(bytes32[] memory leaves) public pure returns (bytes32[] memory) {
    require(leaves.length > 0, 'Expected non-zero number of leaves');

    bytes32[] memory tree = new bytes32[](2 * leaves.length - 1);

    for (uint256 i = 0; i < leaves.length; i++) {
      tree[tree.length - 1 - i] = leaves[i];
    }

    for (int256 i = int256(tree.length - 1 - leaves.length); i >= 0; i--) {
      tree[uint256(i)] = hashPair(tree[leftChildIndex(uint256(i))], tree[rightChildIndex(uint256(i))]);
    }

    return tree;
  }

  function hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32) {
    return left < right ? keccak256(bytes.concat(left, right)) : keccak256(bytes.concat(right, left));
  }

  function leftChildIndex(uint256 i) internal pure returns (uint256) {
    return 2 * i + 1;
  }

  function rightChildIndex(uint256 i) internal pure returns (uint256) {
    return 2 * i + 2;
  }

  function getProof(bytes32[] memory tree, uint256 index) public pure returns (bytes32[] memory) {
    checkLeafNode(tree, index);

    bytes32[] memory proof;
    while (index > 0) {
      proof = concatenate(proof, tree[siblingIndex(index)]);
      index = parentIndex(index);
    }
    return proof;
  }

  function checkLeafNode(bytes32[] memory tree, uint256 index) internal pure {
    require(index < tree.length, 'Invalid leaf index');
  }

  function siblingIndex(uint256 index) internal pure returns (uint256) {
    if (index % 2 == 0) {
      return index - 1;
    } else {
      return index + 1;
    }
  }

  function parentIndex(uint256 index) internal pure returns (uint256) {
    return (index - 1) / 2;
  }

  function concatenate(bytes32[] memory a, bytes32 b) internal pure returns (bytes32[] memory) {
    bytes32[] memory concatenated = new bytes32[](a.length + 1);
    for (uint256 i = 0; i < a.length; i++) {
      concatenated[i] = a[i];
    }
    concatenated[a.length] = b;
    return concatenated;
  }

  function getIndex(bytes32[] memory tree, bytes32 leaf) public pure returns (uint256) {
    for (uint256 i = 0; i < tree.length; i++) {
      if (tree[i] == leaf) {
        return i;
      }
    }
    revert('Leaf not found');
  }
}
