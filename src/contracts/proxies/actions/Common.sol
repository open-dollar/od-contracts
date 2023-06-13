// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';

// solhint-disable
// TODO: enable linter
contract Common {
  // Internal functions

  function _coinJoin_join(address _apt, address _safeHandler, uint256 _wad) internal {
    // NOTE: assumes systemCoin uses 18 decimals
    // Approves adapter to take the COIN amount
    CoinJoin(_apt).systemCoin().approve(_apt, _wad);
    // Joins COIN into the safeEngine
    CoinJoin(_apt).join(_safeHandler, _wad);
  }

  // Public functions
  function coinJoin_join(address _apt, address _safeHandler, uint256 _wad) public {
    // Gets COIN from the user's wallet
    CoinJoin(_apt).systemCoin().transferFrom(msg.sender, address(this), _wad);

    _coinJoin_join(_apt, _safeHandler, _wad);
  }
}
