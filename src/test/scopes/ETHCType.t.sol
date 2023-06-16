// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {BaseCType} from '@test/scopes/BaseCType.t.sol';

abstract contract ETHCType is BaseCType {
  function _cType() internal virtual override returns (bytes32) {
    return bytes32('ETH-A');
  }
}