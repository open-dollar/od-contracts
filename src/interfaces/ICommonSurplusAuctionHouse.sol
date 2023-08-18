// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

interface ICommonSurplusAuctionHouse {
  // --- Events ---
  event StartAuction(
    uint256 indexed _id,
    address indexed _auctioneer,
    uint256 _blockTimestamp,
    uint256 _amountToSell,
    uint256 _amountToRaise,
    uint256 _auctionDeadline
  );

  event RestartAuction(uint256 indexed _id, uint256 _blockTimestamp, uint256 _auctionDeadline);

  event IncreaseBidSize(
    uint256 indexed _id,
    address _bidder,
    uint256 _blockTimestamp,
    uint256 _raisedAmount,
    uint256 _soldAmount,
    uint256 _bidExpiry
  );

  event SettleAuction(uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount);

  // --- Errors ---
  error SAH_AuctionNeverStarted();
  error SAH_AuctionNotFinished();
  error SAH_AuctionAlreadyExpired();
  error SAH_BidAlreadyPlaced();
  error SAH_BidAlreadyExpired();
  error SAH_AmountsNotMatching();
  error SAH_BidNotHigher();
  error SAH_InsufficientIncrease();
  error SAH_HighBidderNotSet();

  // --- Data ---
  struct Auction {
    // Bid size (how many protocol tokens are offered per system coins sold)
    uint256 bidAmount; // [wad]
    // How many system coins are sold in an auction
    uint256 amountToSell; // [rad]
    // Who the high bidder is
    address highBidder;
    // When the latest bid expires and the auction can be settled
    uint256 bidExpiry; // [unix epoch time]
    // Hard deadline for the auction after which no more bids can be placed
    uint256 auctionDeadline; // [unix epoch time]
  }

  // solhint-disable-next-line func-name-mixedcase
  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _auctionHouseType);

  function auctions(uint256 _id) external view returns (Auction memory _auction);
  // solhint-disable-next-line private-vars-leading-underscore
  function _auctions(uint256 _id)
    external
    view
    returns (
      uint256 _bidAmount,
      uint256 _amountToSell,
      address _highBidder,
      uint256 _bidExpiry,
      uint256 _auctionDeadline
    );

  function auctionsStarted() external view returns (uint256 _auctionsStarted);

  // --- Registry ---
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function protocolToken() external view returns (IProtocolToken _protocolToken);

  // --- Auction ---
  function startAuction(uint256 /* RAD */ _amountToSell, uint256 /* WAD */ _initialBid) external returns (uint256 _id);
  function restartAuction(uint256 _id) external;
  function increaseBidSize(uint256 _id, uint256 /* RAD */ _amountToBuy, uint256 /* WAD */ _bid) external;
  function settleAuction(uint256 _id) external;
}
