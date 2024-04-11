// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC721Receiver} from '@openzeppelin/token/ERC721/IERC721Receiver.sol';

contract SCWallet is IERC721Receiver {
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }
}

contract Bad_SCWallet {
  function nftReceiver() external returns (uint256) {
    return 1234;
  }
}
