// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

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

  struct SurplusAuctionHouseParams {
    // Minimum bid increase compared to the last bid in order to take the new one in consideration
    uint256 bidIncrease; // [wad]
    // How long the auction lasts after a new bid is submitted
    uint256 bidDuration; // [seconds]
    // Total length of the auction
    uint256 totalAuctionLength; // [seconds]
    uint256 recyclingPercentage;
  }

  // solhint-disable-next-line func-name-mixedcase
  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _auctionHouseType);
  // solhint-disable-next-line func-name-mixedcase
  function SURPLUS_AUCTION_TYPE() external view returns (bytes32 _surplusAuctionHouseType);

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
  function protocolTokenBidReceiver() external view returns (address _protocolTokenBidReceiver);

  // --- Params ---
  function params() external view returns (SurplusAuctionHouseParams memory _sahParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (uint256 _bidIncrease, uint256 _bidDuration, uint256 _totalAuctionLength, uint256 _recyclingPercentage);

  // --- Auction ---
  function startAuction(uint256 /* RAD */ _amountToSell, uint256 /* WAD */ _initialBid) external returns (uint256 _id);
  function restartAuction(uint256 _id) external;
  function increaseBidSize(uint256 _id, uint256 /* RAD */ _amountToBuy, uint256 /* WAD */ _bid) external;
  function settleAuction(uint256 _id) external;
  function terminateAuctionPrematurely(uint256 _id) external;
}
