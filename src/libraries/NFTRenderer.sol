// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Strings} from '@openzeppelin/utils/Strings.sol';
import {Base64} from '@openzeppelin/utils/Base64.sol';

library NFTRenderer {
  using Strings for uint256;

  struct VaultParams {
    bytes32 cType;
    address handler;
    uint256 tokenId;
    uint256 collat;
    uint256 debt;
    uint256 ratio;
    uint256 fee;
  }

  function render(VaultParams memory params) external pure returns (string memory) {
    string memory image = _renderImage();
    string memory description = _renderDescription();

    string memory json = string.concat(
      '{"name":"Open Dollar Vault",',
      '"description":"',
      description,
      '",',
      '"image":"data:image/svg+xml;base64,',
      Base64.encode(bytes(image)),
      '"}'
    );

    return string.concat('data:application/json;base64,', Base64.encode(bytes(json)));
  }

  function _renderImage() internal pure returns (string memory image) {}

  function _renderDescription() internal pure returns (string memory image) {}
}
