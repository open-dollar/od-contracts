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

import {ISAFEEngine as SAFEEngineLike} from '../../interfaces/ISAFEEngine.sol';
import {IToken as DSTokenLike} from '../../interfaces/external/IToken.sol';
import {ISystemCoin as CollateralLike} from '../../interfaces/external/ISystemCoin.sol';

/*
    Here we provide ETHJoin adapter (for native Ether) to connect the 
    SAFEEngine to arbitrary external token implementations, creating a 
    bounded context for the SAFEEngine. 
    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.
    Adapters need to implement two basic methods:
      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system
*/

contract ETHJoin {
  // --- Auth ---
  mapping(address => uint256) public authorizedAccounts;
  /**
   * @notice Add auth to an account
   * @param account Account to add auth to
   */

  function addAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 1;
    emit AddAuthorization(account);
  }
  /**
   * @notice Remove auth from an account
   * @param account Account to remove auth from
   */

  function removeAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 0;
    emit RemoveAuthorization(account);
  }
  /**
   * @notice Checks whether msg.sender can call a restricted function
   *
   */

  modifier isAuthorized() {
    require(authorizedAccounts[msg.sender] == 1, 'ETHJoin/account-not-authorized');
    _;
  }

  // SAFE database
  SAFEEngineLike public safeEngine;
  // Collateral type name
  bytes32 public collateralType;
  // Whether this contract is enabled or not
  uint256 public contractEnabled;
  // Number of decimals ETH has
  uint256 public decimals;

  // --- Events ---
  event AddAuthorization(address account);
  event RemoveAuthorization(address account);
  event DisableContract();
  event Join(address sender, address account, uint256 wad);
  event Exit(address sender, address account, uint256 wad);

  constructor(address safeEngine_, bytes32 collateralType_) {
    authorizedAccounts[msg.sender] = 1;
    contractEnabled = 1;
    safeEngine = SAFEEngineLike(safeEngine_);
    collateralType = collateralType_;
    decimals = 18;
    emit AddAuthorization(msg.sender);
  }
  /**
   * @notice Disable this contract
   */

  function disableContract() external isAuthorized {
    contractEnabled = 0;
    emit DisableContract();
  }
  /**
   * @notice Join ETH in the system
   * @param account Account that will receive the ETH representation inside the system
   *
   */

  function join(address account) external payable {
    require(contractEnabled == 1, 'ETHJoin/contract-not-enabled');
    require(int256(msg.value) >= 0, 'ETHJoin/overflow');
    safeEngine.modifyCollateralBalance(collateralType, account, int256(msg.value));
    emit Join(msg.sender, account, msg.value);
  }
  /**
   * @notice Exit ETH from the system
   * @param account Account that will receive the ETH representation inside the system
   *
   */

  function exit(address payable account, uint256 wad) external {
    require(int256(wad) >= 0, 'ETHJoin/overflow');
    safeEngine.modifyCollateralBalance(collateralType, msg.sender, -int256(wad));
    emit Exit(msg.sender, account, wad);
    account.transfer(wad);
  }
}
