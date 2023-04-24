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

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {IToken as DSTokenLike} from '@interfaces/external/IToken.sol';
import {ISystemCoin as CollateralLike} from '@interfaces/external/ISystemCoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

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

contract CoinJoin is Authorizable {
  // SAFE database
  SAFEEngineLike public safeEngine;
  // Coin created by the system; this is the external, ERC-20 representation, not the internal 'coinBalance'
  DSTokenLike public systemCoin;
  // Whether this contract is enabled or not
  uint256 public contractEnabled;
  // Number of decimals the system coin has
  uint256 public decimals;

  // --- Events ---
  event DisableContract();
  event Join(address sender, address account, uint256 wad);
  event Exit(address sender, address account, uint256 wad);

  // --- Init ---
  constructor(address safeEngine_, address systemCoin_) Authorizable(msg.sender) {
    contractEnabled = 1;
    safeEngine = SAFEEngineLike(safeEngine_);
    systemCoin = DSTokenLike(systemCoin_);
    decimals = 18;
  }

  /**
   * @notice Disable this contract
   */
  function disableContract() external isAuthorized {
    contractEnabled = 0;
    emit DisableContract();
  }

  uint256 constant RAY = 10 ** 27;

  function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x, 'CoinJoin/mul-overflow');
  }

  /**
   * @notice Join system coins in the system
   * @dev Exited coins have 18 decimals but inside the system they have 45 (rad) decimals.
   *          When we join, the amount (wad) is multiplied by 10**27 (ray)
   * @param account Account that will receive the joined coins
   * @param wad Amount of external coins to join (18 decimal number)
   *
   */
  function join(address account, uint256 wad) external {
    safeEngine.transferInternalCoins(address(this), account, multiply(RAY, wad));
    systemCoin.burn(msg.sender, wad);
    emit Join(msg.sender, account, wad);
  }

  /**
   * @notice Exit system coins from the system and inside 'Coin.sol'
   * @dev Inside the system, coins have 45 (rad) decimals but outside of it they have 18 decimals (wad).
   *          When we exit, we specify a wad amount of coins and then the contract automatically multiplies
   *          wad by 10**27 to move the correct 45 decimal coin amount to this adapter
   * @param account Account that will receive the exited coins
   * @param wad Amount of internal coins to join (18 decimal number that will be multiplied by ray)
   *
   */
  function exit(address account, uint256 wad) external {
    require(contractEnabled == 1, 'CoinJoin/contract-not-enabled');
    safeEngine.transferInternalCoins(msg.sender, address(this), multiply(RAY, wad));
    systemCoin.mint(account, wad);
    emit Exit(msg.sender, account, wad);
  }
}
