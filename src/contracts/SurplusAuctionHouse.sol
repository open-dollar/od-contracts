// SPDX-License-Identifier: GPL-3.0
/// SurplusAuctionHouse.sol

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

import {ISurplusAuctionHouse, SAFEEngineLike, TokenLike} from '@interfaces/ISurplusAuctionHouse.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contract-utils/Disableable.sol';

import {WAD, HUNDRED} from '@libraries/Math.sol';

// This thing lets you auction surplus for protocol tokens. 50% of the protocol tokens are sent to another address and the rest are burned
contract SurplusAuctionHouse is Authorizable, Disableable, ISurplusAuctionHouse {
  // --- Data ---
  // Bid data for each separate auction
  mapping(uint256 => Bid) public bids;

  // SAFE database
  SAFEEngineLike public safeEngine;
  // Protocol token address
  TokenLike public protocolToken;
  // Receiver of protocol tokens
  address public protocolTokenBidReceiver;

  // Minimum bid increase compared to the last bid in order to take the new one in consideration
  uint256 public bidIncrease = 1.05e18; // [wad]
  // How long the auction lasts after a new bid is submitted
  uint48 public bidDuration = 3 hours; // [seconds]
  // Total length of the auction
  uint48 public totalAuctionLength = 2 days; // [seconds]
  // Number of auctions started up until now
  uint256 public auctionsStarted;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');
  bytes32 public constant SURPLUS_AUCTION_TYPE = bytes32('MIXED-STRAT');
  uint256 public recyclingPercentage;

  // --- Init ---
  constructor(address _safeEngine, address _protocolToken, uint256 _recyclingPercentage) Authorizable(msg.sender) {
    safeEngine = SAFEEngineLike(_safeEngine);
    protocolToken = TokenLike(_protocolToken);
    recyclingPercentage = _recyclingPercentage;
  }

  // --- Admin ---
  /**
   * @notice Modify uint256 parameters
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _parameter, uint256 _data) external isAuthorized {
    if (_parameter == 'bidIncrease') bidIncrease = _data;
    else if (_parameter == 'bidDuration') bidDuration = uint48(_data);
    else if (_parameter == 'totalAuctionLength') totalAuctionLength = uint48(_data);
    else revert('SurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(_parameter, _data);
  }

  /**
   * @notice Modify address parameters
   * @param _parameter The name of the parameter modified
   * @param _addr New address value
   */
  function modifyParameters(bytes32 _parameter, address _addr) external isAuthorized {
    require(_addr != address(0), 'SurplusAuctionHouse/invalid-address');
    if (_parameter == 'protocolTokenBidReceiver') protocolTokenBidReceiver = _addr;
    else revert('SurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(_parameter, _addr);
  }

  /**
   * @notice Disable the auction house (usually called by AccountingEngine)
   *
   */
  function disableContract() external isAuthorized whenEnabled {
    _disableContract();
    safeEngine.transferInternalCoins(address(this), msg.sender, safeEngine.coinBalance(address(this)));
  }

  // --- Auction ---
  /**
   * @notice Start a new surplus auction
   * @param _amountToSell Total amount of system coins to sell (rad)
   * @param _initialBid Initial protocol token bid (wad)
   */
  function startAuction(
    uint256 _amountToSell,
    uint256 _initialBid
  ) external isAuthorized whenEnabled returns (uint256 _id) {
    require(
      recyclingPercentage == 0 || protocolTokenBidReceiver != address(0), 'SurplusAuctionHouse/null-prot-token-receiver'
    );
    _id = ++auctionsStarted;

    bids[_id].bidAmount = _initialBid;
    bids[_id].amountToSell = _amountToSell;
    bids[_id].highBidder = msg.sender;
    bids[_id].auctionDeadline = uint48(block.timestamp) + totalAuctionLength;

    safeEngine.transferInternalCoins(msg.sender, address(this), _amountToSell);

    emit StartAuction(_id, auctionsStarted, _amountToSell, _initialBid, bids[_id].auctionDeadline);
  }

  /**
   * @notice Restart an auction if no bids were submitted for it
   * @param _id ID of the auction to restart
   */
  function restartAuction(uint256 _id) external {
    require(bids[_id].auctionDeadline < block.timestamp, 'SurplusAuctionHouse/not-finished');
    require(bids[_id].bidExpiry == 0, 'SurplusAuctionHouse/bid-already-placed');
    bids[_id].auctionDeadline = uint48(block.timestamp) + totalAuctionLength;
    emit RestartAuction(_id, bids[_id].auctionDeadline);
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param _id ID of the auction you want to submit the bid for
   * @param _amountToBuy Amount of system coins to buy (rad)
   * @param _bid New bid submitted (wad)
   */
  function increaseBidSize(uint256 _id, uint256 _amountToBuy, uint256 _bid) external whenEnabled {
    require(bids[_id].highBidder != address(0), 'SurplusAuctionHouse/high-bidder-not-set');
    require(
      bids[_id].bidExpiry > block.timestamp || bids[_id].bidExpiry == 0, 'SurplusAuctionHouse/bid-already-expired'
    );
    require(bids[_id].auctionDeadline > block.timestamp, 'SurplusAuctionHouse/auction-already-expired');

    require(_amountToBuy == bids[_id].amountToSell, 'SurplusAuctionHouse/amounts-not-matching');
    require(_bid > bids[_id].bidAmount, 'SurplusAuctionHouse/bid-not-higher');
    require(_bid * WAD >= bidIncrease * bids[_id].bidAmount, 'SurplusAuctionHouse/insufficient-increase');

    if (msg.sender != bids[_id].highBidder) {
      protocolToken.move(msg.sender, bids[_id].highBidder, bids[_id].bidAmount);
      bids[_id].highBidder = msg.sender;
    }
    protocolToken.move(msg.sender, address(this), _bid - bids[_id].bidAmount);

    bids[_id].bidAmount = _bid;
    bids[_id].bidExpiry = uint48(block.timestamp) + bidDuration;

    emit IncreaseBidSize(_id, msg.sender, _amountToBuy, _bid, bids[_id].bidExpiry);
  }

  /**
   * @notice Settle/finish an auction
   * @param _id ID of the auction to settle
   */
  function settleAuction(uint256 _id) external whenEnabled {
    require(
      bids[_id].bidExpiry != 0 && (bids[_id].bidExpiry < block.timestamp || bids[_id].auctionDeadline < block.timestamp),
      'SurplusAuctionHouse/not-finished'
    );
    safeEngine.transferInternalCoins(address(this), bids[_id].highBidder, bids[_id].amountToSell);

    uint256 _amountToSend = bids[_id].bidAmount * recyclingPercentage / HUNDRED;
    if (_amountToSend > 0) {
      protocolToken.push(protocolTokenBidReceiver, _amountToSend);
      // protocolToken.move(address(this), protocolTokenBidReceiver, _amountToSend);
    }

    uint256 _amountToBurn = bids[_id].bidAmount - _amountToSend;
    if (_amountToBurn > 0) {
      protocolToken.burn(address(this), _amountToBurn);
    }

    delete bids[_id];
    emit SettleAuction(_id);
  }

  /**
   * @notice Terminate an auction prematurely.
   * @param _id ID of the auction to settle/terminate
   */
  function terminateAuctionPrematurely(uint256 _id) external whenDisabled {
    require(bids[_id].highBidder != address(0), 'SurplusAuctionHouse/high-bidder-not-set');
    protocolToken.push(bids[_id].highBidder, bids[_id].bidAmount);
    // protocolToken.move(address(this), bids[_id].highBidder, bids[_id].bidAmount);
    emit TerminateAuctionPrematurely(_id, msg.sender, bids[_id].highBidder, bids[_id].bidAmount);
    delete bids[_id];
  }
}
