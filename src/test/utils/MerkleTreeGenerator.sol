// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

contract MerkleTreeGenerator {
  error LengthMismatch();
  error EmptyArray();

  function generateMerkleTree(
    address[] memory addresses,
    uint256[] memory amounts
  ) public pure returns (bytes32[] memory) {
    if (addresses.length != amounts.length) revert LengthMismatch();
    if (addresses.length == 0) revert EmptyArray();

    uint256 n = addresses.length;
    uint256 treeSize = 2 * n - 1;
    bytes32[] memory tree = new bytes32[](treeSize);

    // Generate leaf nodes
    for (uint256 i = 0; i < n; i++) {
      tree[n - 1 + i] = keccak256(abi.encodePacked(addresses[i], amounts[i]));
    }

    // Generate intermediate nodes
    for (int256 i = int256(n) - 2; i >= 0; i--) {
      tree[uint256(i)] = hashPair(tree[2 * uint256(i) + 1], tree[2 * uint256(i) + 2]);
    }

    return tree;
  }

  function hashPair(bytes32 a, bytes32 b) public pure returns (bytes32) {
    return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
  }

  function _efficientHash(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
    assembly {
      mstore(0x00, a)
      mstore(0x20, b)
      value := keccak256(0x00, 0x40)
    }
  }
}
