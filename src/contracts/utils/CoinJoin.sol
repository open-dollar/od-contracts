// SPDX-License-Identifier: GPL-3.0
/// BasicTokenAdapters.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {ICoinJoin, ISAFEEngine, IToken} from '@interfaces/utils/ICoinJoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {RAY} from '@libraries/Math.sol';

/*
    Here we provide CoinJoin adapter (for connecting internal coin balances) 
    to connect the SAFEEngine to arbitrary external token implementations, 
    creating a bounded context for the SAFEEngine.
    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.
    Adapters need to implement two basic methods:
      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system
*/

contract CoinJoin is Authorizable, Disableable, ICoinJoin {
  // --- Data ---
  // SAFE database
  ISAFEEngine public safeEngine;
  // Coin created by the system; this is the external, ERC-20 representation, not the internal 'coinBalance'
  IToken public systemCoin;
  // Number of decimals the system coin has
  uint256 public decimals;

  // --- Init ---
  constructor(address _safeEngine, address _systemCoin) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine);
    systemCoin = IToken(_systemCoin);
    decimals = 18;
  }

  /**
   * @notice Join system coins in the system
   * @dev Exited coins have 18 decimals but inside the system they have 45 (rad) decimals.
   *          When we join, the amount (wad) is multiplied by 10**27 (ray)
   * @param _account Account that will receive the joined coins
   * @param _wad Amount of external coins to join (18 decimal number)
   *
   */
  function join(address _account, uint256 _wad) external {
    safeEngine.transferInternalCoins(address(this), _account, RAY * _wad);
    systemCoin.burn(msg.sender, _wad);
    emit Join(msg.sender, _account, _wad);
  }

  /**
   * @notice Exit system coins from the system and inside 'Coin.sol'
   * @dev Inside the system, coins have 45 (rad) decimals but outside of it they have 18 decimals (wad).
   *          When we exit, we specify a wad amount of coins and then the contract automatically multiplies
   *          wad by 10**27 to move the correct 45 decimal coin amount to this adapter
   * @param _account Account that will receive the exited coins
   * @param _wad Amount of internal coins to join (18 decimal number that will be multiplied by ray)
   *
   */
  function exit(address _account, uint256 _wad) external whenEnabled {
    safeEngine.transferInternalCoins(msg.sender, address(this), RAY * _wad);
    systemCoin.mint(_account, _wad);
    emit Exit(msg.sender, _account, _wad);
  }
}
