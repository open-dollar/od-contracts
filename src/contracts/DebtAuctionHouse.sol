// SPDX-License-Identifier: GPL-3.0
/// DebtAuctionHouse.sol

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

import {
  IDebtAuctionHouse, ISAFEEngine, IToken, IAccountingEngine, GLOBAL_PARAM
} from '@interfaces/IDebtAuctionHouse.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Math, WAD} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';

// This thing creates protocol tokens on demand in return for system coins
contract DebtAuctionHouse is Authorizable, Disableable, IDebtAuctionHouse {
  using Encoding for bytes;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('DEBT');

  // --- Data ---
  // Bid data for each separate auction
  mapping(uint256 => Bid) public bids;
  // Number of auctions started up until now
  uint256 public auctionsStarted;
  // Accumulator for all debt auctions currently not settled
  uint256 public activeDebtAuctions;

  // --- Registry ---
  // SAFE database
  ISAFEEngine public safeEngine;
  // Protocol token address
  IToken public protocolToken;
  // Accounting engine
  address public accountingEngine;

  // --- Params ---
  DebtAuctionHouseParams internal _params;

  function params() external view returns (DebtAuctionHouseParams memory _dahParams) {
    return _params;
  }

  // --- Init ---
  constructor(address _safeEngine, address _protocolToken) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine);
    protocolToken = IToken(_protocolToken);

    _params = DebtAuctionHouseParams({
      bidDecrease: 1.05e18,
      amountSoldIncrease: 1.5e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });
  }

  // --- Shutdown ---
  /**
   * @notice Disable the auction house (usually called by the AccountingEngine)
   */
  function disableContract() external isAuthorized {
    _disableContract();
    accountingEngine = msg.sender;
    delete activeDebtAuctions;
  }

  // --- Auction ---
  /**
   * @notice Start a new debt auction
   * @param _incomeReceiver Who receives the auction proceeds
   * @param _amountToSell Amount of protocol tokens to sell (wad)
   * @param _initialBid Initial bid size (rad)
   */
  function startAuction(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid
  ) external isAuthorized whenEnabled returns (uint256 _id) {
    _id = ++auctionsStarted;

    bids[_id].bidAmount = _initialBid;
    bids[_id].amountToSell = _amountToSell;
    bids[_id].highBidder = _incomeReceiver;
    bids[_id].auctionDeadline = uint48(block.timestamp) + _params.totalAuctionLength;

    ++activeDebtAuctions;

    emit StartAuction(
      _id, auctionsStarted, _amountToSell, _initialBid, _incomeReceiver, bids[_id].auctionDeadline, activeDebtAuctions
    );
  }

  /**
   * @notice Restart an auction if no bids were submitted for it
   * @param _id ID of the auction to restart
   */
  function restartAuction(uint256 _id) external {
    if (_id == 0 || _id > auctionsStarted) revert DAH_AuctionNeverStarted();
    if (bids[_id].auctionDeadline > block.timestamp) revert DAH_AuctionNotFinished();
    if (bids[_id].bidExpiry != 0) revert DAH_BidAlreadyPlaced();
    bids[_id].amountToSell = (_params.amountSoldIncrease * bids[_id].amountToSell) / WAD;
    bids[_id].auctionDeadline = uint48(block.timestamp) + _params.totalAuctionLength;
    emit RestartAuction(_id, bids[_id].auctionDeadline);
  }

  /**
   * @notice Decrease the protocol token amount you're willing to receive in
   *         exchange for providing the same amount of system coins being raised by the auction
   * @param _id ID of the auction for which you want to submit a new bid
   * @param _amountToBuy Amount of protocol tokens to buy (must be smaller than the previous proposed amount) (wad)
   * @param _bid New system coin bid (must always equal the total amount raised by the auction) (rad)
   */
  function decreaseSoldAmount(uint256 _id, uint256 _amountToBuy, uint256 _bid) external whenEnabled {
    if (bids[_id].highBidder == address(0)) revert DAH_HighBidderNotSet();
    if (bids[_id].bidExpiry <= block.timestamp && bids[_id].bidExpiry != 0) revert DAH_BidAlreadyExpired();
    if (bids[_id].auctionDeadline <= block.timestamp) revert DAH_AuctionAlreadyExpired();

    if (_bid != bids[_id].bidAmount) revert DAH_NotMatchingBid();
    if (_amountToBuy >= bids[_id].amountToSell) revert DAH_AmountBoughtNotLower();
    if (_params.bidDecrease * _amountToBuy > bids[_id].amountToSell * WAD) revert DAH_InsufficientDecrease();

    safeEngine.transferInternalCoins(msg.sender, bids[_id].highBidder, _bid);

    // on first bid submitted, clear as much totalOnAuctionDebt as possible
    if (bids[_id].bidExpiry == 0) {
      uint256 _totalOnAuctionDebt = IAccountingEngine(bids[_id].highBidder).totalOnAuctionDebt();
      IAccountingEngine(bids[_id].highBidder).cancelAuctionedDebtWithSurplus(Math.min(_bid, _totalOnAuctionDebt));
    }

    bids[_id].highBidder = msg.sender;
    bids[_id].amountToSell = _amountToBuy;
    bids[_id].bidExpiry = uint48(block.timestamp) + _params.bidDuration;

    emit DecreaseSoldAmount(_id, msg.sender, _amountToBuy, _bid, bids[_id].bidExpiry);
  }

  /**
   * @notice Settle/finish an auction
   * @param _id ID of the auction to settle
   */
  function settleAuction(uint256 _id) external whenEnabled {
    if (
      bids[_id].bidExpiry == 0 || (bids[_id].bidExpiry > block.timestamp && bids[_id].auctionDeadline > block.timestamp)
    ) revert DAH_AuctionNotFinished();
    protocolToken.mint(bids[_id].highBidder, bids[_id].amountToSell);
    --activeDebtAuctions;
    delete bids[_id];
    emit SettleAuction(_id, activeDebtAuctions);
  }

  /**
   * @notice Terminate an auction prematurely
   * @param _id ID of the auction to terminate
   */
  function terminateAuctionPrematurely(uint256 _id) external whenDisabled {
    if (bids[_id].highBidder == address(0)) revert DAH_HighBidderNotSet();
    safeEngine.createUnbackedDebt(accountingEngine, bids[_id].highBidder, bids[_id].bidAmount);
    emit TerminateAuctionPrematurely(_id, msg.sender, bids[_id].highBidder, bids[_id].bidAmount, activeDebtAuctions);
    delete bids[_id];
  }

  // --- Admin ---
  /**
   * @notice Modify parameters
   * @param _param The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _param, bytes memory _data) external isAuthorized whenEnabled {
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    if (_param == 'protocolToken') protocolToken = IToken(_address);
    else if (_param == 'accountingEngine') accountingEngine = _address;
    else if (_param == 'bidDecrease') _params.bidDecrease = _uint256;
    else if (_param == 'amountSoldIncrease') _params.amountSoldIncrease = _uint256;
    else if (_param == 'bidDuration') _params.bidDuration = uint48(_uint256);
    else if (_param == 'totalAuctionLength') _params.totalAuctionLength = uint48(_uint256);
    else revert UnrecognizedParam();

    emit ModifyParameters(_param, GLOBAL_PARAM, _data);
  }
}
