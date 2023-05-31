// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IToken} from '@interfaces/external/IToken.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface IDebtAuctionHouse is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---
  event StartAuction(
    uint256 indexed _id,
    uint256 _auctionsStarted,
    uint256 _amountToSell,
    uint256 _initialBid,
    address indexed _incomeReceiver,
    uint256 indexed _auctionDeadline,
    uint256 _activeDebtAuctions
  );
  event RestartAuction(uint256 indexed _id, uint256 _auctionDeadline);
  event DecreaseSoldAmount(
    uint256 indexed _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry
  );
  event SettleAuction(uint256 indexed _id, uint256 _activeDebtAuctions);
  event TerminateAuctionPrematurely(
    uint256 indexed _id, address _sender, address _highBidder, uint256 _bidAmount, uint256 _activeDebtAuctions
  );

  // --- Errors ---
  error DAH_AuctionNeverStarted();
  error DAH_AuctionNotFinished();
  error DAH_AuctionAlreadyExpired();
  error DAH_BidAlreadyPlaced();
  error DAH_BidAlreadyExpired();
  error DAH_NotMatchingBid();
  error DAH_AmountBoughtNotLower();
  error DAH_InsufficientDecrease();
  error DAH_HighBidderNotSet();

  // --- Data ---
  struct Bid {
    // Bid size
    uint256 bidAmount; // [rad]
    // How many protocol tokens are sold in an auction
    uint256 amountToSell; // [wad]
    // Who the high bidder is
    address highBidder;
    // When the latest bid expires and the auction can be settled
    uint48 bidExpiry; // [unix epoch time]
    // Hard deadline for the auction after which no more bids can be placed
    uint48 auctionDeadline; // [unix epoch time]
  }

  struct DebtAuctionHouseParams {
    // Minimum bid increase compared to the last bid in order to take the new one in consideration
    uint256 bidDecrease; // [wad]
    // Increase in protocol tokens sold in case an auction is restarted
    uint256 amountSoldIncrease; // [wad]
    // How long the auction lasts after a new bid is submitted
    uint48 bidDuration; // [seconds]
    // Total length of the auction
    uint48 totalAuctionLength; // [seconds]
  }

  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _AUCTION_HOUSE_TYPE);

  function bids(uint256 _id)
    external
    view
    returns (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline);
  function auctionsStarted() external view returns (uint256 _auctionsStarted);
  function activeDebtAuctions() external view returns (uint256 _activeDebtAuctions);

  // --- Registry ---
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function protocolToken() external view returns (IToken _protocolToken);
  function accountingEngine() external view returns (address _accountingEngine);

  // --- Params ---
  function params() external view returns (DebtAuctionHouseParams memory _params);

  // --- Auction ---
  function startAuction(
    address _incomeReceiver,
    uint256 /* wad */ _amountToSell,
    uint256 /* rad */ _initialBid
  ) external returns (uint256 _id);
  function restartAuction(uint256 _id) external;
  function decreaseSoldAmount(uint256 _id, uint256 /* wad */ _amountToBuy, uint256 /* rad */ _bid) external;
  function settleAuction(uint256 _id) external;
  function terminateAuctionPrematurely(uint256 _id) external;
}
