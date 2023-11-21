// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface IDebtAuctionHouse is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when a new auction is started
   * @param  _id Id of the auction
   * @param  _auctioneer Address who started the auction
   * @param  _blockTimestamp Time when the auction was started
   * @param  _amountToSell How much protocol tokens are initially offered [wad]
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
  event DecreaseSoldAmount(
    uint256 indexed _id,
    address _bidder,
    uint256 _blockTimestamp,
    uint256 _raisedAmount,
    uint256 _soldAmount,
    uint256 _bidExpiry
  );

  /**
   * @notice Emitted when an auction is settled
   * @dev    An auction is settled after the winning bid or the auction expire
   * @param  _id Id of the auction
   * @param  _blockTimestamp Time when the auction was settled
   * @param  _highBidder Who won the auction
   * @param  _raisedAmount Amount of system coins raised in the auction [rad]
   */
  event SettleAuction(uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount);

  /**
   * @notice Emitted when an auction is terminated prematurely
   * @param  _id Id of the auction
   * @param  _blockTimestamp Time when the auction was terminated
   * @param  _highBidder Who won the auction
   * @param  _raisedAmount Amount of system coins raised in the auction [rad]
   */
  event TerminateAuctionPrematurely(
    uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount
  );

  // --- Errors ---

  /// @dev Throws when trying to restart an auction that never started
  error DAH_AuctionNeverStarted();
  /// @dev Throws when trying to restart an auction that is still active
  error DAH_AuctionNotFinished();
  /// @dev Throws when trying to restart an auction that already has a winning bid
  error DAH_BidAlreadyPlaced();
  /// @dev Throws when trying to bid in an auction that already has expired
  error DAH_AuctionAlreadyExpired();
  /// @dev Throws when trying to bid in an auction that has a bid already expired
  error DAH_BidAlreadyExpired();
  /// @dev Throws when trying to bid in an auction with a bid that doesn't match the current bid
  error DAH_NotMatchingBid();
  /// @dev Throws when trying to place a bid that is not lower than the current bid
  error DAH_AmountBoughtNotLower();
  /// @dev Throws when trying to place a bid not lower than the current bid threshold
  error DAH_InsufficientDecrease();
  /// @dev Throws when prematurely terminating an auction that has no bids
  error DAH_HighBidderNotSet();

  // --- Data ---

  struct Auction {
    // Bid size
    uint256 /* RAD  */ bidAmount;
    // How many protocol tokens are sold in an auction
    uint256 /* WAD  */ amountToSell;
    // Who the high bidder is
    address /*      */ highBidder;
    // When the latest bid expires and the auction can be settled
    uint256 /* unix */ bidExpiry;
    // Hard deadline for the auction after which no more bids can be placed
    uint256 /* unix */ auctionDeadline;
  }

  struct DebtAuctionHouseParams {
    // Minimum bid increase compared to the last bid in order to take the new one in consideration
    uint256 /* WAD %   */ bidDecrease;
    // Increase in protocol tokens sold in case an auction is restarted
    uint256 /* WAD %   */ amountSoldIncrease;
    // How long the auction lasts after a new bid is submitted
    uint256 /* seconds */ bidDuration;
    // Total length of the auction
    uint256 /* seconds */ totalAuctionLength;
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
   * @notice Unpacked data of an auction
   * @param  _id Id of the auction
   * @return _bidAmount How much protocol tokens are to be minted [wad]
   * @return _amountToSell How many system coins are raised [rad]
   * @return _highBidder Address of the highest bidder
   * @return _bidExpiry Time when the latest bid expires and the auction can be settled
   * @return _auctionDeadline Time when the auction expires
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

  /// @notice Total amount of debt auctions created
  function auctionsStarted() external view returns (uint256 _auctionsStarted);

  /// @notice Total amount of simultaneous active debt auctions
  function activeDebtAuctions() external view returns (uint256 _activeDebtAuctions);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  /// @notice Address of the ProtocolToken contract
  function protocolToken() external view returns (IProtocolToken _protocolToken);
  /// @notice Address of the AccountingEngine contract
  function accountingEngine() external view returns (address _accountingEngine);

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _dahParams Auction house parameters struct
   */
  function params() external view returns (DebtAuctionHouseParams memory _dahParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _bidDecrease Minimum bid increase compared to the last bid in order to take the new one in consideration [wad %]
   * @return _amountSoldIncrease Increase in protocol tokens sold in case an auction is restarted [wad %]
   * @return _bidDuration How long the auction lasts after a new bid is submitted [seconds]
   * @return _totalAuctionLength Total length of the auction [seconds]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (uint256 _bidDecrease, uint256 _amountSoldIncrease, uint256 _bidDuration, uint256 _totalAuctionLength);

  // --- Auction ---

  /**
   * @notice Start a new debt auction
   * @param  _incomeReceiver Who receives the auction proceeds
   * @param  _amountToSell Initial amount of protocol tokens to be minted [wad]
   * @param  _initialBid Amount of debt to be sold [rad]
   * @return _id Id of the auction
   */
  function startAuction(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid
  ) external returns (uint256 _id);

  /**
   * @notice Restart an auction if no bids were placed
   * @dev    An auction can be restarted if the auction expired with no bids
   * @param  _id Id of the auction
   */
  function restartAuction(uint256 _id) external;

  /**
   * @notice Decrease the protocol token amount you're willing to receive in
   *         exchange for providing the same amount of system coins being raised by the auction
   * @param  _id ID of the auction for which you want to submit a new bid
   * @param  _amountToBuy Amount of protocol tokens to buy (must be smaller than the previous proposed amount) [wad]
   */
  function decreaseSoldAmount(uint256 _id, uint256 _amountToBuy) external;

  /**
   * @notice Settle an auction
   * @dev    Can only be called after the auction expired with a winning bid
   * @param  _id Id of the auction
   */
  function settleAuction(uint256 _id) external;

  /**
   * @notice Terminate an auction prematurely
   * @param  _id Id of the auction
   * @dev    Can only be called after the contract is disabled
   * @dev    The method creates an unbacked debt position in the AccountingEngine for the remaining debt
   */
  function terminateAuctionPrematurely(uint256 _id) external;
}
