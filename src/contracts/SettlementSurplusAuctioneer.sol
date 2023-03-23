// SPDX-License-Identifier: GPL-3.0
/// SettlementSurplusAuctioneer.sol

// Copyright (C) 2020 Reflexer Labs, INC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {IAccountingEngine as AccountingEngineLike} from '../interfaces/IAccountingEngine.sol';
import {ISAFEEngine as SAFEEngineLike} from '../interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse as SurplusAuctionHouseLike} from '../interfaces/ISurplusAuctionHouse.sol';

import {Math} from './utils/Math.sol';

contract SettlementSurplusAuctioneer is Math {
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
    require(authorizedAccounts[msg.sender] == 1, 'SettlementSurplusAuctioneer/account-not-authorized');
    _;
  }

  AccountingEngineLike public accountingEngine;
  SurplusAuctionHouseLike public surplusAuctionHouse;
  SAFEEngineLike public safeEngine;

  // Last time when this contract triggered a surplus auction
  uint256 public lastSurplusAuctionTime;

  // --- Events ---
  event AddAuthorization(address account);
  event RemoveAuthorization(address account);
  event ModifyParameters(bytes32 parameter, address addr);
  event AuctionSurplus(uint256 indexed id, uint256 lastSurplusAuctionTime, uint256 coinBalance);

  constructor(address _accountingEngine, address _surplusAuctionHouse) {
    authorizedAccounts[msg.sender] = 1;
    accountingEngine = AccountingEngineLike(_accountingEngine);
    surplusAuctionHouse = SurplusAuctionHouseLike(_surplusAuctionHouse);
    safeEngine = SAFEEngineLike(address(accountingEngine.safeEngine()));
    safeEngine.approveSAFEModification(address(surplusAuctionHouse));
    emit AddAuthorization(msg.sender);
  }

  // --- Administration ---
  /**
   * @notice Modify address params
   * @param parameter The name of the contract whose address will be changed
   * @param addr New address for the contract
   */
  function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
    if (parameter == 'accountingEngine') {
      accountingEngine = AccountingEngineLike(addr);
    } else if (parameter == 'surplusAuctionHouse') {
      safeEngine.denySAFEModification(address(surplusAuctionHouse));
      surplusAuctionHouse = SurplusAuctionHouseLike(addr);
      safeEngine.approveSAFEModification(address(surplusAuctionHouse));
    } else {
      revert('SettlementSurplusAuctioneer/modify-unrecognized-param');
    }
    emit ModifyParameters(parameter, addr);
  }

  // --- Core Logic ---
  /**
   * @notice Auction surplus. The process is very similar to the one in the AccountingEngine.
   * @dev The contract reads surplus auction parameters from the AccountingEngine and uses them to
   *      start a new auction.
   */
  function auctionSurplus() external returns (uint256 id) {
    require(accountingEngine.contractEnabled() == 0, 'SettlementSurplusAuctioneer/accounting-engine-still-enabled');
    require(
      block.timestamp >= addition(lastSurplusAuctionTime, accountingEngine.surplusAuctionDelay()),
      'SettlementSurplusAuctioneer/surplus-auction-delay-not-passed'
    );
    lastSurplusAuctionTime = block.timestamp;
    uint256 amountToSell = (safeEngine.coinBalance(address(this)) < accountingEngine.surplusAuctionAmountToSell())
      ? safeEngine.coinBalance(address(this))
      : accountingEngine.surplusAuctionAmountToSell();
    if (amountToSell > 0) {
      id = surplusAuctionHouse.startAuction(amountToSell, 0);
      emit AuctionSurplus(id, lastSurplusAuctionTime, safeEngine.coinBalance(address(this)));
    }
  }
}
