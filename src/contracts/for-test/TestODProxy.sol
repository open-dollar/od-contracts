// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC721Receiver} from '@openzeppelin/token/ERC721/IERC721Receiver.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

contract TestODProxy is ODProxy, IERC721Receiver {
  constructor(address _owner) ODProxy(_owner) {}

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }
}
