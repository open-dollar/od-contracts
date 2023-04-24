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
    Here we provide CollateralJoin adapter (for well behaved ERC20 tokens) 
    to connect the SAFEEngine to arbitrary external token implementations, 
    creating a bounded context for the SAFEEngine. 
    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.
    Adapters need to implement two basic methods:
      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system
*/

contract CollateralJoin is Authorizable {
  // SAFE database
  SAFEEngineLike public safeEngine;
  // Collateral type name
  bytes32 public collateralType;
  // Actual collateral token contract
  CollateralLike public collateral;
  // How many decimals the collateral token has
  uint256 public decimals;
  // Whether this adapter contract is enabled or not
  uint256 public contractEnabled;

  // --- Events ---
  event DisableContract();
  event Join(address sender, address account, uint256 wad);
  event Exit(address sender, address account, uint256 wad);

  // --- Init ---
  constructor(address _safeEngine, bytes32 _collateralType, address _collateral) Authorizable(msg.sender) {
    contractEnabled = 1;
    safeEngine = SAFEEngineLike(_safeEngine);
    collateralType = _collateralType;
    collateral = CollateralLike(_collateral);
    decimals = collateral.decimals();
    require(decimals == 18, 'CollateralJoin/non-18-decimals');
  }

  /**
   * @notice Disable this contract
   */
  function disableContract() external isAuthorized {
    contractEnabled = 0;
    emit DisableContract();
  }

  /**
   * @notice Join collateral in the system
   * @dev This function locks collateral in the adapter and creates a 'representation' of
   *      the locked collateral inside the system. This adapter assumes that the collateral
   *      has 18 decimals
   * @param account Account from which we transferFrom collateral and add it in the system
   * @param wad Amount of collateral to transfer in the system (represented as a number with 18 decimals)
   *
   */
  function join(address account, uint256 wad) external {
    require(contractEnabled == 1, 'CollateralJoin/contract-not-enabled');
    require(int256(wad) >= 0, 'CollateralJoin/overflow');
    safeEngine.modifyCollateralBalance(collateralType, account, int256(wad));
    require(collateral.transferFrom(msg.sender, address(this), wad), 'CollateralJoin/failed-transfer');
    emit Join(msg.sender, account, wad);
  }

  /**
   * @notice Exit collateral from the system
   * @dev This function destroys the collateral representation from inside the system
   *      and exits the collateral from this adapter. The adapter assumes that the collateral
   *      has 18 decimals
   * @param account Account to which we transfer the collateral
   * @param wad Amount of collateral to transfer to 'account' (represented as a number with 18 decimals)
   *
   */
  function exit(address account, uint256 wad) external {
    require(wad <= 2 ** 255, 'CollateralJoin/overflow');
    safeEngine.modifyCollateralBalance(collateralType, msg.sender, -int256(wad));
    require(collateral.transfer(account, wad), 'CollateralJoin/failed-transfer');
    emit Exit(msg.sender, account, wad);
  }
}
