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

import {WAD, HUNDRED, FIFTY} from '@libraries/Math.sol';

/*
   This thing lets you auction some system coins in return for protocol tokens that are then burnt
*/

contract BurningSurplusAuctionHouse is Authorizable {
  // --- Data ---
  struct Bid {
    // Bid size (how many protocol tokens are offered per system coins sold)
    uint256 bidAmount; // [wad]
    // How many system coins are sold in an auction
    uint256 amountToSell; // [rad]
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
  // Whether the contract is settled or not
  uint256 public contractEnabled;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');
  bytes32 public constant SURPLUS_AUCTION_TYPE = bytes32('BURNING');

  // --- Events ---
  event ModifyParameters(bytes32 parameter, uint256 data);
  event RestartAuction(uint256 id, uint256 auctionDeadline);
  event IncreaseBidSize(uint256 id, address highBidder, uint256 amountToBuy, uint256 bid, uint256 bidExpiry);
  event StartAuction(
    uint256 indexed id, uint256 auctionsStarted, uint256 amountToSell, uint256 initialBid, uint256 auctionDeadline
  );
  event SettleAuction(uint256 indexed id);
  event DisableContract();
  event TerminateAuctionPrematurely(uint256 indexed id, address sender, address highBidder, uint256 bidAmount);

  // --- Init ---
  constructor(address _safeEngine, address _protocolToken) {
    _addAuthorization(msg.sender);
    safeEngine = SAFEEngineLike(_safeEngine);
    protocolToken = TokenLike(_protocolToken);
    contractEnabled = 1;
    emit AddAuthorization(msg.sender);
  }

  // --- Admin ---
  /**
   * @notice Modify auction parameters
   * @param parameter The name of the parameter modified
   * @param data New value for the parameter
   */
  function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
    if (parameter == 'bidIncrease') bidIncrease = data;
    else if (parameter == 'bidDuration') bidDuration = uint48(data);
    else if (parameter == 'totalAuctionLength') totalAuctionLength = uint48(data);
    else revert('BurningSurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }

  // --- Auction ---
  /**
   * @notice Start a new surplus auction
   * @param amountToSell Total amount of system coins to sell (rad)
   * @param initialBid Initial protocol token bid (wad)
   */
  function startAuction(uint256 amountToSell, uint256 initialBid) external isAuthorized returns (uint256 id) {
    require(contractEnabled == 1, 'BurningSurplusAuctionHouse/contract-not-enabled');
    require(auctionsStarted < type(uint256).max, 'BurningSurplusAuctionHouse/overflow');
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
    require(bids[id].auctionDeadline < block.timestamp, 'BurningSurplusAuctionHouse/not-finished');
    require(bids[id].bidExpiry == 0, 'BurningSurplusAuctionHouse/bid-already-placed');
    bids[id].auctionDeadline = uint48(block.timestamp) + totalAuctionLength;
    emit RestartAuction(id, bids[id].auctionDeadline);
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param id ID of the auction you want to submit the bid for
   * @param amountToBuy Amount of system coins to buy (rad)
   * @param bid New bid submitted (wad)
   */
  function increaseBidSize(uint256 id, uint256 amountToBuy, uint256 bid) external {
    require(contractEnabled == 1, 'BurningSurplusAuctionHouse/contract-not-enabled');
    require(bids[id].highBidder != address(0), 'BurningSurplusAuctionHouse/high-bidder-not-set');
    require(
      bids[id].bidExpiry > block.timestamp || bids[id].bidExpiry == 0, 'BurningSurplusAuctionHouse/bid-already-expired'
    );
    require(bids[id].auctionDeadline > block.timestamp, 'BurningSurplusAuctionHouse/auction-already-expired');

    require(amountToBuy == bids[id].amountToSell, 'BurningSurplusAuctionHouse/amounts-not-matching');
    require(bid > bids[id].bidAmount, 'BurningSurplusAuctionHouse/bid-not-higher');
    require(bid * WAD >= bidIncrease * bids[id].bidAmount, 'BurningSurplusAuctionHouse/insufficient-increase');

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
    require(contractEnabled == 1, 'BurningSurplusAuctionHouse/contract-not-enabled');
    require(
      bids[id].bidExpiry != 0 && (bids[id].bidExpiry < block.timestamp || bids[id].auctionDeadline < block.timestamp),
      'BurningSurplusAuctionHouse/not-finished'
    );
    safeEngine.transferInternalCoins(address(this), bids[id].highBidder, bids[id].amountToSell);
    protocolToken.burn(address(this), bids[id].bidAmount);
    delete bids[id];
    emit SettleAuction(id);
  }

  /**
   * @notice Disable the auction house (usually called by AccountingEngine)
   *
   */
  function disableContract() external isAuthorized {
    contractEnabled = 0;
    safeEngine.transferInternalCoins(address(this), msg.sender, safeEngine.coinBalance(address(this)));
    emit DisableContract();
  }

  /**
   * @notice Terminate an auction prematurely.
   * @param id ID of the auction to settle/terminate
   */
  function terminateAuctionPrematurely(uint256 id) external {
    require(contractEnabled == 0, 'BurningSurplusAuctionHouse/contract-still-enabled');
    require(bids[id].highBidder != address(0), 'BurningSurplusAuctionHouse/high-bidder-not-set');
    protocolToken.push(bids[id].highBidder, bids[id].bidAmount);
    // NOTE: replaced move(this,...) for push(...) (requires allowance)
    // protocolToken.move(address(this), bids[id].highBidder, bids[id].bidAmount);
    emit TerminateAuctionPrematurely(id, msg.sender, bids[id].highBidder, bids[id].bidAmount);
    delete bids[id];
  }
}

// This thing lets you auction surplus for protocol tokens that are then sent to another address

contract RecyclingSurplusAuctionHouse is Authorizable {
  // --- Data ---
  struct Bid {
    // Bid size (how many protocol tokens are offered per system coins sold)
    uint256 bidAmount; // [wad]
    // How many system coins are sold in an auction
    uint256 amountToSell; // [rad]
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
  // Receiver of protocol tokens
  address public protocolTokenBidReceiver;

  // Minimum bid increase compared to the last bid in order to take the new one in consideration
  uint256 public bidIncrease = 1.05e18; // [wad]
  // How long the auction lasts after a new bid is submitted
  uint48 public bidDuration = 3 hours; // [seconds]
  // Total length of the auction
  uint48 public totalAuctionLength = 2 days; // [seconds]
  // Number of auctions started up until now
  uint256 public auctionsStarted = 0;
  // Whether the contract is settled or not
  uint256 public contractEnabled;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');
  bytes32 public constant SURPLUS_AUCTION_TYPE = bytes32('RECYCLING');

  // --- Events ---
  event ModifyParameters(bytes32 parameter, uint256 data);
  event ModifyParameters(bytes32 parameter, address addr);
  event RestartAuction(uint256 id, uint256 auctionDeadline);
  event IncreaseBidSize(uint256 id, address highBidder, uint256 amountToBuy, uint256 bid, uint256 bidExpiry);
  event StartAuction(
    uint256 indexed id, uint256 auctionsStarted, uint256 amountToSell, uint256 initialBid, uint256 auctionDeadline
  );
  event SettleAuction(uint256 indexed id);
  event DisableContract();
  event TerminateAuctionPrematurely(uint256 indexed id, address sender, address highBidder, uint256 bidAmount);

  // --- Init ---
  constructor(address _safeEngine, address _protocolToken) {
    _addAuthorization(msg.sender);
    safeEngine = SAFEEngineLike(_safeEngine);
    protocolToken = TokenLike(_protocolToken);
    contractEnabled = 1;
    emit AddAuthorization(msg.sender);
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
    else revert('RecyclingSurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }

  /**
   * @notice Modify address parameters
   * @param parameter The name of the parameter modified
   * @param addr New address value
   */
  function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
    require(addr != address(0), 'RecyclingSurplusAuctionHouse/invalid-address');
    if (parameter == 'protocolTokenBidReceiver') protocolTokenBidReceiver = addr;
    else revert('RecyclingSurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(parameter, addr);
  }

  // --- Auction ---
  /**
   * @notice Start a new surplus auction
   * @param amountToSell Total amount of system coins to sell (rad)
   * @param initialBid Initial protocol token bid (wad)
   */
  function startAuction(uint256 amountToSell, uint256 initialBid) external isAuthorized returns (uint256 id) {
    require(contractEnabled == 1, 'RecyclingSurplusAuctionHouse/contract-not-enabled');
    require(auctionsStarted < type(uint256).max, 'RecyclingSurplusAuctionHouse/overflow');
    require(protocolTokenBidReceiver != address(0), 'RecyclingSurplusAuctionHouse/null-prot-token-receiver');
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
    require(bids[id].auctionDeadline < block.timestamp, 'RecyclingSurplusAuctionHouse/not-finished');
    require(bids[id].bidExpiry == 0, 'RecyclingSurplusAuctionHouse/bid-already-placed');
    bids[id].auctionDeadline = uint48(block.timestamp) + totalAuctionLength;
    emit RestartAuction(id, bids[id].auctionDeadline);
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param id ID of the auction you want to submit the bid for
   * @param amountToBuy Amount of system coins to buy (rad)
   * @param bid New bid submitted (wad)
   */
  function increaseBidSize(uint256 id, uint256 amountToBuy, uint256 bid) external {
    require(contractEnabled == 1, 'RecyclingSurplusAuctionHouse/contract-not-enabled');
    require(bids[id].highBidder != address(0), 'RecyclingSurplusAuctionHouse/high-bidder-not-set');
    require(
      bids[id].bidExpiry > block.timestamp || bids[id].bidExpiry == 0,
      'RecyclingSurplusAuctionHouse/bid-already-expired'
    );
    require(bids[id].auctionDeadline > block.timestamp, 'RecyclingSurplusAuctionHouse/auction-already-expired');

    require(amountToBuy == bids[id].amountToSell, 'RecyclingSurplusAuctionHouse/amounts-not-matching');
    require(bid > bids[id].bidAmount, 'RecyclingSurplusAuctionHouse/bid-not-higher');
    require(bid * WAD >= bidIncrease * bids[id].bidAmount, 'RecyclingSurplusAuctionHouse/insufficient-increase');

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
    require(contractEnabled == 1, 'RecyclingSurplusAuctionHouse/contract-not-enabled');
    require(
      bids[id].bidExpiry != 0 && (bids[id].bidExpiry < block.timestamp || bids[id].auctionDeadline < block.timestamp),
      'RecyclingSurplusAuctionHouse/not-finished'
    );
    safeEngine.transferInternalCoins(address(this), bids[id].highBidder, bids[id].amountToSell);
    protocolToken.push(protocolTokenBidReceiver, bids[id].bidAmount);
    // protocolToken.move(address(this), protocolTokenBidReceiver, bids[id].bidAmount);
    delete bids[id];
    emit SettleAuction(id);
  }

  /**
   * @notice Disable the auction house (usually called by AccountingEngine)
   *
   */
  function disableContract() external isAuthorized {
    contractEnabled = 0;
    safeEngine.transferInternalCoins(address(this), msg.sender, safeEngine.coinBalance(address(this)));
    emit DisableContract();
  }

  /**
   * @notice Terminate an auction prematurely.
   * @param id ID of the auction to settle/terminate
   */
  function terminateAuctionPrematurely(uint256 id) external {
    require(contractEnabled == 0, 'RecyclingSurplusAuctionHouse/contract-still-enabled');
    require(bids[id].highBidder != address(0), 'RecyclingSurplusAuctionHouse/high-bidder-not-set');
    protocolToken.push(bids[id].highBidder, bids[id].bidAmount);
    // protocolToken.move(address(this), bids[id].highBidder, bids[id].bidAmount);
    emit TerminateAuctionPrematurely(id, msg.sender, bids[id].highBidder, bids[id].bidAmount);
    delete bids[id];
  }
}

// This thing lets you auction surplus for protocol tokens. 50% of the protocol tokens are sent to another address and the rest are burned

contract MixedStratSurplusAuctionHouse is Authorizable {
  // --- Data ---
  struct Bid {
    // Bid size (how many protocol tokens are offered per system coins sold)
    uint256 bidAmount; // [wad]
    // How many system coins are sold in an auction
    uint256 amountToSell; // [rad]
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
  // Receiver of protocol tokens
  address public protocolTokenBidReceiver;

  // Minimum bid increase compared to the last bid in order to take the new one in consideration
  uint256 public bidIncrease = 1.05e18; // [wad]
  // How long the auction lasts after a new bid is submitted
  uint48 public bidDuration = 3 hours; // [seconds]
  // Total length of the auction
  uint48 public totalAuctionLength = 2 days; // [seconds]
  // Number of auctions started up until now
  uint256 public auctionsStarted = 0;
  // Whether the contract is settled or not
  uint256 public contractEnabled;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');
  bytes32 public constant SURPLUS_AUCTION_TYPE = bytes32('MIXED-STRAT');

  // --- Events ---
  event ModifyParameters(bytes32 parameter, uint256 data);
  event ModifyParameters(bytes32 parameter, address addr);
  event RestartAuction(uint256 id, uint256 auctionDeadline);
  event IncreaseBidSize(uint256 id, address highBidder, uint256 amountToBuy, uint256 bid, uint256 bidExpiry);
  event StartAuction(
    uint256 indexed id, uint256 auctionsStarted, uint256 amountToSell, uint256 initialBid, uint256 auctionDeadline
  );
  event SettleAuction(uint256 indexed id);
  event DisableContract();
  event TerminateAuctionPrematurely(uint256 indexed id, address sender, address highBidder, uint256 bidAmount);

  // --- Init ---
  constructor(address _safeEngine, address _protocolToken) {
    _addAuthorization(msg.sender);
    safeEngine = SAFEEngineLike(_safeEngine);
    protocolToken = TokenLike(_protocolToken);
    contractEnabled = 1;
    emit AddAuthorization(msg.sender);
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
    else revert('MixedStratSurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }

  /**
   * @notice Modify address parameters
   * @param parameter The name of the parameter modified
   * @param addr New address value
   */
  function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
    require(addr != address(0), 'MixedStratSurplusAuctionHouse/invalid-address');
    if (parameter == 'protocolTokenBidReceiver') protocolTokenBidReceiver = addr;
    else revert('MixedStratSurplusAuctionHouse/modify-unrecognized-param');
    emit ModifyParameters(parameter, addr);
  }

  // --- Auction ---
  /**
   * @notice Start a new surplus auction
   * @param amountToSell Total amount of system coins to sell (rad)
   * @param initialBid Initial protocol token bid (wad)
   */
  function startAuction(uint256 amountToSell, uint256 initialBid) external isAuthorized returns (uint256 id) {
    require(contractEnabled == 1, 'MixedStratSurplusAuctionHouse/contract-not-enabled');
    require(auctionsStarted < type(uint256).max, 'MixedStratSurplusAuctionHouse/overflow');
    require(protocolTokenBidReceiver != address(0), 'MixedStratSurplusAuctionHouse/null-prot-token-receiver');
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
    require(bids[id].auctionDeadline < block.timestamp, 'MixedStratSurplusAuctionHouse/not-finished');
    require(bids[id].bidExpiry == 0, 'MixedStratSurplusAuctionHouse/bid-already-placed');
    bids[id].auctionDeadline = uint48(block.timestamp) + totalAuctionLength;
    emit RestartAuction(id, bids[id].auctionDeadline);
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param id ID of the auction you want to submit the bid for
   * @param amountToBuy Amount of system coins to buy (rad)
   * @param bid New bid submitted (wad)
   */
  function increaseBidSize(uint256 id, uint256 amountToBuy, uint256 bid) external {
    require(contractEnabled == 1, 'MixedStratSurplusAuctionHouse/contract-not-enabled');
    require(bids[id].highBidder != address(0), 'MixedStratSurplusAuctionHouse/high-bidder-not-set');
    require(
      bids[id].bidExpiry > block.timestamp || bids[id].bidExpiry == 0,
      'MixedStratSurplusAuctionHouse/bid-already-expired'
    );
    require(bids[id].auctionDeadline > block.timestamp, 'MixedStratSurplusAuctionHouse/auction-already-expired');

    require(amountToBuy == bids[id].amountToSell, 'MixedStratSurplusAuctionHouse/amounts-not-matching');
    require(bid > bids[id].bidAmount, 'MixedStratSurplusAuctionHouse/bid-not-higher');
    require(bid * WAD >= bidIncrease * bids[id].bidAmount, 'MixedStratSurplusAuctionHouse/insufficient-increase');

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
    require(contractEnabled == 1, 'MixedStratSurplusAuctionHouse/contract-not-enabled');
    require(
      bids[id].bidExpiry != 0 && (bids[id].bidExpiry < block.timestamp || bids[id].auctionDeadline < block.timestamp),
      'MixedStratSurplusAuctionHouse/not-finished'
    );
    safeEngine.transferInternalCoins(address(this), bids[id].highBidder, bids[id].amountToSell);

    uint256 amountToSend = bids[id].bidAmount * FIFTY / HUNDRED;
    if (amountToSend > 0) {
      protocolToken.push(protocolTokenBidReceiver, amountToSend);
      // protocolToken.move(address(this), protocolTokenBidReceiver, amountToSend);
    }

    uint256 amountToBurn = bids[id].bidAmount - amountToSend;
    if (amountToBurn > 0) {
      protocolToken.burn(address(this), amountToBurn);
    }

    delete bids[id];
    emit SettleAuction(id);
  }

  /**
   * @notice Disable the auction house (usually called by AccountingEngine)
   *
   */
  function disableContract() external isAuthorized {
    contractEnabled = 0;
    safeEngine.transferInternalCoins(address(this), msg.sender, safeEngine.coinBalance(address(this)));
    emit DisableContract();
  }

  /**
   * @notice Terminate an auction prematurely.
   * @param id ID of the auction to settle/terminate
   */
  function terminateAuctionPrematurely(uint256 id) external {
    require(contractEnabled == 0, 'MixedStratSurplusAuctionHouse/contract-still-enabled');
    require(bids[id].highBidder != address(0), 'MixedStratSurplusAuctionHouse/high-bidder-not-set');
    protocolToken.push(bids[id].highBidder, bids[id].bidAmount);
    // protocolToken.move(address(this), bids[id].highBidder, bids[id].bidAmount);
    emit TerminateAuctionPrematurely(id, msg.sender, bids[id].highBidder, bids[id].bidAmount);
    delete bids[id];
  }
}
