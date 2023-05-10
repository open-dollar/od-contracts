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

import {ICollateralJoin, SAFEEngineLike, CollateralLike} from '@interfaces/utils/ICollateralJoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Math} from '@libraries/Math.sol';

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

contract CollateralJoin is ICollateralJoin, Authorizable, Disableable {
  using Math for uint256;

  // --- Data ---
  // SAFE database
  SAFEEngineLike public safeEngine;
  // Collateral type name
  bytes32 public collateralType;
  // Actual collateral token contract
  CollateralLike public collateral;
  // How many decimals the collateral token has
  uint256 public decimals;

  // --- Init ---
  constructor(address _safeEngine, bytes32 _collateralType, address _collateral) Authorizable(msg.sender) {
    safeEngine = SAFEEngineLike(_safeEngine);
    collateralType = _collateralType;
    collateral = CollateralLike(_collateral);
    decimals = collateral.decimals();
    require(decimals == 18, 'CollateralJoin/non-18-decimals');
  }

  // --- Shutdown ---
  /**
   * @notice Disable this contract
   */
  function disableContract() external isAuthorized whenEnabled {
    _disableContract();
  }

  /**
   * @notice Join collateral in the system
   * @dev This function locks collateral in the adapter and creates a 'representation' of
   *      the locked collateral inside the system. This adapter assumes that the collateral
   *      has 18 decimals
   * @param _account Account from which we transferFrom collateral and add it in the system
   * @param _wad Amount of collateral to transfer in the system (represented as a number with 18 decimals)
   *
   */
  function join(address _account, uint256 _wad) external whenEnabled {
    safeEngine.modifyCollateralBalance(collateralType, _account, _wad.toIntNotOverflow());
    require(collateral.transferFrom(msg.sender, address(this), _wad), 'CollateralJoin/failed-transfer');
    emit Join(msg.sender, _account, _wad);
  }

  /**
   * @notice Exit collateral from the system
   * @dev This function destroys the collateral representation from inside the system
   *      and exits the collateral from this adapter. The adapter assumes that the collateral
   *      has 18 decimals
   * @param _account Account to which we transfer the collateral
   * @param _wad Amount of collateral to transfer to 'account' (represented as a number with 18 decimals)
   *
   */
  function exit(address _account, uint256 _wad) external {
    safeEngine.modifyCollateralBalance(collateralType, msg.sender, -_wad.toIntNotOverflow());
    require(collateral.transfer(_account, _wad), 'CollateralJoin/failed-transfer');
    emit Exit(msg.sender, _account, _wad);
  }
}
