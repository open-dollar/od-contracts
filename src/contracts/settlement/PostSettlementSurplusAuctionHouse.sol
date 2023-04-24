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

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {IToken as TokenLike} from '@interfaces/external/IToken.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {WAD} from '@libraries/Math.sol';

contract PostSettlementSurplusAuctionHouse is Authorizable {
  // --- Data ---
  struct Bid {
    // Bid size (how many protocol tokens are offered per system coins sold)
    uint256 bidAmount; // [rad]
    // How many system coins are sold in an auction
    uint256 amountToSell; // [wad]
    // Who the high bidder is
    address highBidder;
    // When the latest bid expires and the auction can be settled
    uint48 bidExpiry; // [unix epoch time]
    // Hard deadline for the auction after which no more bids can be placed
    uint48 auctionDeadline; // [unix epoch time]
  }

  // Bid data for each separate auction
  mapping(uint256 => Bid) public bids;

  // SAFE database
  SAFEEngineLike public safeEngine;
  // Protocol token address
  TokenLike public protocolToken;

  // Minimum bid increase compared to the last bid in order to take the new one in consideration
  uint256 public bidIncrease = 1.05e18; // [wad]
  // How long the auction lasts after a new bid is submitted
  uint48 public bidDuration = 3 hours; // [seconds]
  // Total length of the auction
  uint48 public totalAuctionLength = 2 days; // [seconds]
  // Number of auctions started up until now
  uint256 public auctionsStarted = 0;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');

  // --- Events ---
  event ModifyParameters(bytes32 parameter, uint256 data);
  event RestartAuction(uint256 indexed id, uint256 auctionDeadline);
  event IncreaseBidSize(uint256 indexed id, address highBidder, uint256 amountToBuy, uint256 bid, uint256 bidExpiry);
  event StartAuction(
    uint256 indexed id, uint256 auctionsStarted, uint256 amountToSell, uint256 initialBid, uint256 auctionDeadline
  );
  event SettleAuction(uint256 indexed id);

  // --- Init ---
  constructor(address _safeEngine, address _protocolToken) Authorizable(msg.sender) {
    safeEngine = SAFEEngineLike(_safeEngine);
    protocolToken = TokenLike(_protocolToken);
  }

  // --- Admin ---
  /**
   * @notice Modify uint256 parameters
   * @param parameter The name of the parameter modified
   * @param data New value for the parameter
   */
  function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
    if (parameter == 'bidIncrease') bidIncrease = data;
    else if (parameter == 'bidDuration') bidDuration = uint48(data);
    else if (parameter == 'totalAuctionLength') totalAuctionLength = uint48(data);
    else revert('PostSettlementSurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }

  // --- Auction ---
  /**
   * @notice Start a new surplus auction
   * @param amountToSell Total amount of system coins to sell (wad)
   * @param initialBid Initial protocol token bid (rad)
   */
  function startAuction(uint256 amountToSell, uint256 initialBid) external isAuthorized returns (uint256 id) {
    require(auctionsStarted < type(uint256).max, 'PostSettlementSurplusAuctionHouse/overflow');
    id = ++auctionsStarted;

    bids[id].bidAmount = initialBid;
    bids[id].amountToSell = amountToSell;
    bids[id].highBidder = msg.sender;
    bids[id].auctionDeadline = uint48(block.timestamp) + totalAuctionLength;

    safeEngine.transferInternalCoins(msg.sender, address(this), amountToSell);

    emit StartAuction(id, auctionsStarted, amountToSell, initialBid, bids[id].auctionDeadline);
  }

  /**
   * @notice Restart an auction if no bids were submitted for it
   * @param id ID of the auction to restart
   */
  function restartAuction(uint256 id) external {
    require(bids[id].auctionDeadline < block.timestamp, 'PostSettlementSurplusAuctionHouse/not-finished');
    require(bids[id].bidExpiry == 0, 'PostSettlementSurplusAuctionHouse/bid-already-placed');
    bids[id].auctionDeadline = uint48(block.timestamp) + totalAuctionLength;
    emit RestartAuction(id, bids[id].auctionDeadline);
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param id ID of the auction you want to submit the bid for
   * @param amountToBuy Amount of system coins to buy (wad)
   * @param bid New bid submitted (rad)
   */
  function increaseBidSize(uint256 id, uint256 amountToBuy, uint256 bid) external {
    require(bids[id].highBidder != address(0), 'PostSettlementSurplusAuctionHouse/high-bidder-not-set');
    require(
      bids[id].bidExpiry > block.timestamp || bids[id].bidExpiry == 0,
      'PostSettlementSurplusAuctionHouse/bid-already-expired'
    );
    require(bids[id].auctionDeadline > block.timestamp, 'PostSettlementSurplusAuctionHouse/auction-already-expired');

    require(amountToBuy == bids[id].amountToSell, 'PostSettlementSurplusAuctionHouse/amounts-not-matching');
    require(bid > bids[id].bidAmount, 'PostSettlementSurplusAuctionHouse/bid-not-higher');
    require(bid * WAD >= bidIncrease * bids[id].bidAmount, 'PostSettlementSurplusAuctionHouse/insufficient-increase');

    if (msg.sender != bids[id].highBidder) {
      protocolToken.move(msg.sender, bids[id].highBidder, bids[id].bidAmount);
      bids[id].highBidder = msg.sender;
    }
    protocolToken.move(msg.sender, address(this), bid - bids[id].bidAmount);

    bids[id].bidAmount = bid;
    bids[id].bidExpiry = uint48(block.timestamp) + bidDuration;

    emit IncreaseBidSize(id, msg.sender, amountToBuy, bid, bids[id].bidExpiry);
  }

  /**
   * @notice Settle/finish an auction
   * @param id ID of the auction to settle
   */
  function settleAuction(uint256 id) external {
    require(
      bids[id].bidExpiry != 0 && (bids[id].bidExpiry < block.timestamp || bids[id].auctionDeadline < block.timestamp),
      'PostSettlementSurplusAuctionHouse/not-finished'
    );
    safeEngine.transferInternalCoins(address(this), bids[id].highBidder, bids[id].amountToSell);
    protocolToken.burn(address(this), bids[id].bidAmount);
    delete bids[id];
    emit SettleAuction(id);
  }
}
