// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {IToken as TokenLike} from '@interfaces/external/IToken.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface IPostSettlementSurplusAuctionHouse is IAuthorizable, IModifiable {
  struct PostSettlementSAHParams {
    uint256 bidIncrease;
    uint48 bidDuration;
    uint48 totalAuctionLength;
  }

  // --- Events ---
  event RestartAuction(uint256 _id, uint256 _auctionDeadline);
  event IncreaseBidSize(uint256 _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry);
  event StartAuction(
    uint256 indexed _id, uint256 _auctionsStarted, uint256 _amountToSell, uint256 _initialBid, uint256 _auctionDeadline
  );
  event SettleAuction(uint256 indexed _id);

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

  function bids(uint256 _id)
    external
    view
    returns (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline);
  function safeEngine() external view returns (SAFEEngineLike _safeEngine);
  function protocolToken() external view returns (TokenLike _protocolToken);
  function auctionsStarted() external view returns (uint256 _auctionsStarted);
  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _AUCTION_HOUSE_TYPE);
  function SURPLUS_AUCTION_TYPE() external view returns (bytes32 _SURPLUS_AUCTION_TYPE);

  // --- Auction ---
  function startAuction(uint256 /* rad */ _amountToSell, uint256 /* wad */ _initialBid) external returns (uint256 _id);
  function restartAuction(uint256 _id) external;
  function increaseBidSize(uint256 _id, uint256 /* rad */ _amountToBuy, uint256 /* wad */ _bid) external;
  function settleAuction(uint256 _id) external;

  // --- Params ---
  function params() external view returns (PostSettlementSAHParams memory _params);
}
