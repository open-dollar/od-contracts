// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

contract BytesDecoder {
  function decodeAsUint256(bytes memory data) public pure returns (uint256) {
    return abi.decode(data, (uint256));
  }

  function decodeAsInt256(bytes memory data) public pure returns (int256) {
    return abi.decode(data, (int256));
  }

  function decodeAsAddress(bytes memory data) public pure returns (address) {
    return abi.decode(data, (address));
  }

  function decodeAsBytes32(bytes memory data) public pure returns (bytes32) {
    return abi.decode(data, (bytes32));
  }

  function decodeAsBool(bytes memory data) public pure returns (bool) {
    return abi.decode(data, (bool));
  }
}
