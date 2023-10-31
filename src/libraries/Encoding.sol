// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title Encoding
 * @notice This library contains functions for decoding data into common types
 */
library Encoding {
  // --- Methods ---

  /// @dev Decodes a bytes array into a uint256
  function toUint256(bytes memory _data) internal pure returns (uint256 _uint256) {
    assembly {
      _uint256 := mload(add(_data, 0x20))
    }
  }

  /// @dev Decodes a bytes array into an int256
  function toInt256(bytes memory _data) internal pure returns (int256 _int256) {
    assembly {
      _int256 := mload(add(_data, 0x20))
    }
  }

  /// @dev Decodes a bytes array into an address
  function toAddress(bytes memory _data) internal pure returns (address _address) {
    assembly {
      _address := mload(add(_data, 0x20))
    }
  }

  /// @dev Decodes a bytes array into a bool
  function toBool(bytes memory _data) internal pure returns (bool _bool) {
    assembly {
      _bool := mload(add(_data, 0x20))
    }
  }
}
