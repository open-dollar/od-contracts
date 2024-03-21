// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Base_CType} from '@testnet/scopes/Base_CType.t.sol';

abstract contract ETH_CType is Base_CType {
  function _cType() internal virtual override returns (bytes32) {
    return bytes32('ETH-A');
  }
}
