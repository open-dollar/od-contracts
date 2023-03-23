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

pragma solidity 0.6.7;

import {ISAFEEngine as SAFEEngineLike} from '../../interfaces/ISAFEEngine.sol';
import {IToken as DSTokenLike} from '../../interfaces/external/IToken.sol';
import {ISystemCoin as CollateralLike} from '../../interfaces/external/ISystemCoin.sol';

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

contract CollateralJoin {
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
   * @notice Checks whether msg.sender can call an authed function
   *
   */

  modifier isAuthorized() {
    require(authorizedAccounts[msg.sender] == 1, 'CollateralJoin/account-not-authorized');
    _;
  }

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
  event AddAuthorization(address account);
  event RemoveAuthorization(address account);
  event DisableContract();
  event Join(address sender, address account, uint256 wad);
  event Exit(address sender, address account, uint256 wad);

  constructor(address safeEngine_, bytes32 collateralType_, address collateral_) public {
    authorizedAccounts[msg.sender] = 1;
    contractEnabled = 1;
    safeEngine = SAFEEngineLike(safeEngine_);
    collateralType = collateralType_;
    collateral = CollateralLike(collateral_);
    decimals = collateral.decimals();
    require(decimals == 18, 'CollateralJoin/non-18-decimals');
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
