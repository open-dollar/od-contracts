// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';

// solhint-disable
// TODO: enable linter
contract CommonActions {
  error OnlyDelegateCalls();

  address immutable THIS = address(this);

  // Internal functions

  function _coinJoin_join(address _joinAdapter, address _safeHandler, uint256 _wad) internal {
    // NOTE: assumes systemCoin uses 18 decimals
    // Approves adapter to take the COIN amount
    CoinJoin(_joinAdapter).systemCoin().approve(_joinAdapter, _wad);
    // Joins COIN into the safeEngine
    CoinJoin(_joinAdapter).join(_safeHandler, _wad);
  }

  // Public functions
  // TODO: make internal and external
  function coinJoin_join(address _joinAdapter, address _safeHandler, uint256 _wad) public {
    // Gets COIN from the user's wallet
    CoinJoin(_joinAdapter).systemCoin().transferFrom(msg.sender, address(this), _wad);

    _coinJoin_join(_joinAdapter, _safeHandler, _wad);
  }

  modifier delegateCall() {
    if (address(this) == THIS) revert OnlyDelegateCalls();
    _;
  }
}
