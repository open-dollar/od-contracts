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

import {
  ISettlementSurplusAuctioneer,
  IAccountingEngine,
  ISAFEEngine,
  ISurplusAuctionHouse,
  GLOBAL_PARAM
} from '@interfaces/settlement/ISettlementSurplusAuctioneer.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Math} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';

contract SettlementSurplusAuctioneer is Authorizable, ISettlementSurplusAuctioneer {
  using Encoding for bytes;

  // --- Data ---
  // Last time when this contract triggered a surplus auction
  uint256 public lastSurplusTime;

  // --- Registry ---
  IAccountingEngine public accountingEngine;
  ISurplusAuctionHouse public surplusAuctionHouse;
  ISAFEEngine public safeEngine;

  // --- Init ---
  constructor(address _accountingEngine, address _surplusAuctionHouse) Authorizable(msg.sender) {
    accountingEngine = IAccountingEngine(_accountingEngine);
    surplusAuctionHouse = ISurplusAuctionHouse(_surplusAuctionHouse);
    safeEngine = ISAFEEngine(address(accountingEngine.safeEngine()));
    safeEngine.approveSAFEModification(address(surplusAuctionHouse));
  }

  // --- Core Logic ---
  /**
   * @notice Auction surplus. The process is very similar to the one in the AccountingEngine.
   * @dev The contract reads surplus auction parameters from the AccountingEngine and uses them to
   *      start a new auction.
   */
  function auctionSurplus() external returns (uint256 _id) {
    if (accountingEngine.contractEnabled() != 0) revert SSA_AccountingEngineStillEnabled();
    IAccountingEngine.AccountingEngineParams memory _accEngineParams = accountingEngine.params();
    if (block.timestamp < lastSurplusTime + _accEngineParams.surplusDelay) revert SSA_SurplusAuctionDelayNotPassed();
    lastSurplusTime = block.timestamp;
    uint256 _amountToSell = Math.min(safeEngine.coinBalance(address(this)), _accEngineParams.surplusAmount);
    if (_amountToSell > 0) {
      _id = surplusAuctionHouse.startAuction(_amountToSell, 0);
      emit AuctionSurplus(_id, lastSurplusTime, safeEngine.coinBalance(address(this)));
    }
  }

  // --- Admin ---
  /**
   * @notice Modify parameters
   * @param _param The name of the contract whose address will be changed
   * @param _data New address for the contract
   */
  function modifyParameters(bytes32 _param, bytes memory _data) external isAuthorized {
    address _address = _data.toAddress();

    if (_param == 'accountingEngine') accountingEngine = IAccountingEngine(_address);
    else if (_param == 'surplusAuctionHouse') _setSurplusAuctionHouse(_address);
    else revert UnrecognizedParam();

    emit ModifyParameters(_param, GLOBAL_PARAM, _data);
  }

  function _setSurplusAuctionHouse(address _address) internal {
    safeEngine.denySAFEModification(address(surplusAuctionHouse));
    surplusAuctionHouse = ISurplusAuctionHouse(_address);
    safeEngine.approveSAFEModification(_address);
  }
}
