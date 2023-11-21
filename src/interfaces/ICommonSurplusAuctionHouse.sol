// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

interface ICommonSurplusAuctionHouse {
  // --- Events ---

  /**
   * @notice Emitted when a new auction is started
   * @param  _id Id of the auction
   * @param  _auctioneer Address who started the auction
   * @param  _blockTimestamp Time when the auction was started
   * @param  _amountToSell How many protocol tokens are initially bidded [wad]
   * @param  _amountToRaise Amount of system coins to raise [rad]
   * @param  _auctionDeadline Time when the auction expires
   */
  event StartAuction(
    uint256 indexed _id,
    address indexed _auctioneer,
    uint256 _blockTimestamp,
    uint256 _amountToSell,
    uint256 _amountToRaise,
    uint256 _auctionDeadline
  );

  /**
   * @notice Emitted when an auction is restarted
   * @param  _id Id of the auction
   * @param  _blockTimestamp Time when the auction was restarted
   * @param  _auctionDeadline New time when the auction expires
   */
  event RestartAuction(uint256 indexed _id, uint256 _blockTimestamp, uint256 _auctionDeadline);

  /**
   * @notice Emitted when a bid is made in an auction
   * @param  _id Id of the auction
   * @param  _bidder Who made the bid
   * @param  _blockTimestamp Time when the bid was made
   * @param  _raisedAmount Amount of system coins raised in the bid [rad]
   * @param  _soldAmount Amount of protocol tokens offered to buy in the bid [wad]
   * @param  _bidExpiry Time when the bid expires
   */
  event IncreaseBidSize(
    uint256 indexed _id,
    address _bidder,
    uint256 _blockTimestamp,
    uint256 _raisedAmount,
    uint256 _soldAmount,
    uint256 _bidExpiry
  );

  /**
   * @notice Emitted when an auction is settled
   * @param  _id Id of the auction
   * @param  _blockTimestamp Time when the auction was settled
   * @param  _highBidder Who won the auction
   * @param  _raisedAmount Amount of system coins raised in the auction [rad]
   */
  event SettleAuction(uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount);

  // --- Errors ---

  /// @dev Throws when trying to bid in an auction that hasn't started yet
  error SAH_AuctionNeverStarted();
  /// @dev Throws when trying to settle an auction that hasn't finished yet
  error SAH_AuctionNotFinished();
  /// @dev Throws when trying to bid in an auction that has already expired
  error SAH_AuctionAlreadyExpired();
  /// @dev Throws when trying to bid in an auction that has an expired bid
  error SAH_BidAlreadyExpired();
  /// @dev Throws when trying to restart an auction that has an active bid
  error SAH_BidAlreadyPlaced();
  /// @dev Throws when trying to place a bid that differs from the amount to raise
  error SAH_AmountsNotMatching();
  /// @dev Throws when trying to place a bid that is not higher than the previous one
  error SAH_BidNotHigher();
  /// @dev Throws when trying to place a bid that is not higher than the previous one by the minimum increase
  error SAH_InsufficientIncrease();
  /// @dev Throws when trying to prematurely terminate an auction that has no bids
  error SAH_HighBidderNotSet();

  // --- Data ---

  struct Auction {
    // Bid size (how many protocol tokens are offered per system coins sold)
    uint256 /* WAD  */ bidAmount;
    // How many system coins are sold in an auction
    uint256 /* RAD  */ amountToSell;
    // Who the high bidder is
    address /*      */ highBidder;
    // When the latest bid expires and the auction can be settled
    uint256 /* unix */ bidExpiry;
    // Hard deadline for the auction after which no more bids can be placed
    uint256 /* unix */ auctionDeadline;
  }

  /**
   * @notice Type of the auction house
   * @return _auctionHouseType Bytes32 representation of the auction house type
   */
  // solhint-disable-next-line func-name-mixedcase
  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _auctionHouseType);

  /**
   * @notice Data of an auction
   * @param  _id Id of the auction
   * @return _auction Auction data struct
   */
  function auctions(uint256 _id) external view returns (Auction memory _auction);

  /**
   * @notice Raw data of an auction
   * @param  _id Id of the auction
   * @return _bidAmount How many system coins are offered for the protocol tokens [rad]
   * @return _amountToSell How protocol tokens are sold to buy the surplus system coins [wad]
   * @return _highBidder Who the high bidder is
   * @return _bidExpiry When the latest bid expires and the auction can be settled [timestamp]
   * @return _auctionDeadline Hard deadline for the auction after which no more bids can be placed [timestamp]
   */
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

  /// @notice Total amount of surplus auctions created
  function auctionsStarted() external view returns (uint256 _auctionsStarted);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  /// @notice Address of the ProtocolToken contract
  function protocolToken() external view returns (IProtocolToken _protocolToken);

  // --- Auction ---

  /**
   * @notice Start a new surplus auction
   * @param  _amountToSell Total amount of system coins to sell [rad]
   * @param  _initialBid Initial protocol token bid [wad]
   * @return _id ID of the started auction
   */
  function startAuction(uint256 _amountToSell, uint256 _initialBid) external returns (uint256 _id);

  /**
   * @notice Restart an auction if no bids were submitted for it
   * @param  _id ID of the auction to restart
   */
  function restartAuction(uint256 _id) external;

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param  _id ID of the auction you want to submit the bid for
   * @param  _bid New bid submitted [wad]
   */
  function increaseBidSize(uint256 _id, uint256 _bid) external;

  /**
   * @notice Settle/finish an auction
   * @param  _id ID of the auction to settle
   */
  function settleAuction(uint256 _id) external;
}
