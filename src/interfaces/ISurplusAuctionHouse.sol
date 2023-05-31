// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IToken} from '@interfaces/external/IToken.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface ISurplusAuctionHouse is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---
  event StartAuction(
    uint256 indexed _id, uint256 _auctionsStarted, uint256 _amountToSell, uint256 _initialBid, uint256 _auctionDeadline
  );
  event RestartAuction(uint256 indexed _id, uint256 _auctionDeadline);
  event IncreaseBidSize(
    uint256 indexed _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry
  );
  event SettleAuction(uint256 indexed _id);
  event TerminateAuctionPrematurely(uint256 indexed _id, address _sender, address _highBidder, uint256 _bidAmount);

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
  error SAH_NullProtTokenReceiver();

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

  struct SurplusAuctionHouseParams {
    // Minimum bid increase compared to the last bid in order to take the new one in consideration
    uint256 bidIncrease; // [wad]
    // How long the auction lasts after a new bid is submitted
    uint48 bidDuration; // [seconds]
    // Total length of the auction
    uint48 totalAuctionLength; // [seconds]
    uint256 recyclingPercentage;
  }

  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _AUCTION_HOUSE_TYPE);
  function SURPLUS_AUCTION_TYPE() external view returns (bytes32 _SURPLUS_AUCTION_TYPE);

  function bids(uint256 _id)
    external
    view
    returns (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline);
  function auctionsStarted() external view returns (uint256 _auctionsStarted);

  // --- Registry ---
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function protocolToken() external view returns (IToken _protocolToken);
  function protocolTokenBidReceiver() external view returns (address _protocolTokenBidReceiver);

  // --- Params ---
  function params() external view returns (SurplusAuctionHouseParams memory _params);

  // --- Auction ---
  function startAuction(uint256 /* rad */ _amountToSell, uint256 /* wad */ _initialBid) external returns (uint256 _id);
  function restartAuction(uint256 _id) external;
  function increaseBidSize(uint256 _id, uint256 /* rad */ _amountToBuy, uint256 /* wad */ _bid) external;
  function settleAuction(uint256 _id) external;
  function terminateAuctionPrematurely(uint256 _id) external;
}
