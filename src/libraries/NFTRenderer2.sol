// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Strings} from '@openzeppelin/utils/Strings.sol';
import {Base64} from '@openzeppelin/utils/Base64.sol';

library NFTRenderer2 {
  using Strings for uint256;
  using Strings for address;

  struct VaultParams {
    uint256 tokenId;
    uint256 collat;
    uint256 debt;
    uint256 ratio;
    uint256 fee;
    string symbol;
  }

  function render(VaultParams memory params) external pure returns (string memory) {
    string memory image = _renderImage(params);
    string memory description = _renderDescription(params);

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

  function _renderImage(VaultParams memory params) internal pure returns (string memory image) {
    image = string.concat(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 480">',
      '<style>',
      '.tokens { font: bold 30px sans-serif; }',
      '.fee { font: normal 26px sans-serif; }',
      '.tick { font: normal 18px sans-serif; }',
      '</style>',
      '<rect width="300" height="480" fill="hsl(330,40%,40%)" />',
      '<rect x="30" y="30" width="240" height="420" rx="15" ry="15" fill="hsl(330,90%,50%)" stroke="#000" />',
      '<rect x="30" y="87" width="240" height="42" />',
      '<text x="39" y="120" class="tokens" fill="#fff">',
      'Vault ',
      params.tokenId.toString(),
      ': ',
      params.symbol,
      ' / OD',
      '</text>',
      '<rect x="30" y="132" width="240" height="30" />',
      '<text x="39" y="120" dy="36" class="fee" fill="#fff">',
      params.collat.toString(),
      '</text>',
      '<rect x="30" y="165" width="240" height="30" />',
      '<text x="39" y="153" dy="36" class="fee" fill="#fff">',
      params.debt.toString(),
      '</text>',
      '<rect x="30" y="342" width="240" height="24" />',
      '<text x="39" y="360" class="tick" fill="#fff">',
      'ratio: ',
      params.ratio.toString(),
      '</text>',
      '<rect x="30" y="372" width="240" height="24" />',
      '<text x="39" y="360" dy="30" class="tick" fill="#fff">',
      'fee: ',
      params.fee.toString(),
      '</text>',
      '</svg>'
    );
  }

  function _renderDescription(VaultParams memory params) internal pure returns (string memory description) {
    description = string.concat(
      params.tokenId.toString(),
      ' ',
      params.symbol,
      ' ',
      params.collat.toString(),
      ' ',
      params.debt.toString(),
      ' ',
      params.ratio.toString(),
      ' ',
      params.fee.toString()
    );
  }
}
