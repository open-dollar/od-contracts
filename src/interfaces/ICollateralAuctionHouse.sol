// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ICollateralAuctionHouse is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when a new auction is started
   * @param  _id Id of the auction
   * @param  _auctioneer Address who started the auction
   * @param  _blockTimestamp Time when the auction was started
   * @param  _amountToSell How much collateral is sold in an auction [wad]
   * @param  _amountToRaise Total/max amount of coins to raise [rad]
   */
  event StartAuction(
    uint256 indexed _id,
    address indexed _auctioneer,
    uint256 _blockTimestamp,
    uint256 _amountToSell,
    uint256 _amountToRaise
  );

  // NOTE: Doesn't have RestartAuction event

  /**
   * @notice Emitted when a bid is made in an auction
   * @param  _id Id of the auction
   * @param  _bidder Who made the bid
   * @param  _blockTimestamp Time when the bid was made
   * @param  _raisedAmount Amount of coins raised in the bid [rad]
   * @param  _soldAmount Amount of collateral sold in the bid [wad]
   */
  event BuyCollateral(
    uint256 indexed _id, address _bidder, uint256 _blockTimestamp, uint256 _raisedAmount, uint256 _soldAmount
  );

  /**
   * @notice Emitted when an auction is settled
   * @dev    An auction is settled when either all collateral is sold or all coins are raised
   * @param  _id Id of the auction
   * @param  _blockTimestamp Time when the auction was settled
   * @param  _leftoverReceiver Who receives leftover collateral that is not sold in the auction (usually the liquidated SAFE)
   * @param  _leftoverCollateral Amount of leftover collateral that is not sold in the auction [wad]
   */
  event SettleAuction(
    uint256 indexed _id, uint256 _blockTimestamp, address _leftoverReceiver, uint256 _leftoverCollateral
  );

  /**
   * @notice Emitted when an auction is terminated prematurely
   * @param  _id Id of the auction
   * @param  _blockTimestamp Time when the auction was terminated
   * @param  _leftoverReceiver Who receives leftover collateral that is not sold in the auction (usually the liquidated SAFE)
   * @param  _leftoverCollateral Amount of leftover collateral that is not sold in the auction [wad]
   */
  event TerminateAuctionPrematurely(
    uint256 indexed _id, uint256 _blockTimestamp, address _leftoverReceiver, uint256 _leftoverCollateral
  );

  // --- Errors ---

  /// @notice Throws when the redemption price is invalid
  error CAH_InvalidRedemptionPriceProvided();
  /// @notice Throws when the collateral price is invalid
  error CAH_CollateralOracleInvalidValue();
  /// @notice Throws when trying to start an auction without collateral to sell
  error CAH_NoCollateralForSale();
  /// @notice Throws when trying to start an auction without coins to raise
  error CAH_NothingToRaise();
  /// @notice Throws when trying to start an auction with a dusty amount to raise
  error CAH_DustyAuction();
  /// @notice Throws when trying to bid in a nonexistent auction
  error CAH_InexistentAuction();
  /// @notice Throws when trying to bid an invalid amount
  error CAH_InvalidBid();
  /// @notice Throws when the resulting bid amount is null
  error CAH_NullBoughtAmount();
  /// @notice Throws when the resulting bid leftover to raise is invalid
  error CAH_InvalidLeftToRaise();

  // --- Data ---

  struct CollateralAuctionHouseParams {
    // Minimum acceptable bid
    uint256 /* WAD   */ minimumBid;
    // Minimum discount at which collateral is being sold
    uint256 /* WAD % */ minDiscount;
    // Maximum discount at which collateral is being sold
    uint256 /* WAD % */ maxDiscount;
    // Rate at which the discount will be updated in an auction
    uint256 /* RAY   */ perSecondDiscountUpdateRate;
  }

  struct Auction {
    // How much collateral is sold in an auction
    uint256 /* WAD  */ amountToSell;
    // Total/max amount of coins to raise
    uint256 /* RAD  */ amountToRaise;
    // Time when the auction was created
    uint256 /* unix */ initialTimestamp;
    // Who receives leftover collateral that is not sold in the auction (usually the liquidated SAFE)
    address /*      */ forgoneCollateralReceiver;
    // Who receives the coins raised by the auction (usually the AccountingEngine)
    address /*      */ auctionIncomeRecipient;
  }

  /**
   * @notice Type of the auction house
   * @return _auctionHouseType Bytes32 representation of the auction house type
   */
  // solhint-disable-next-line func-name-mixedcase
  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _auctionHouseType);

  /**
   * @notice Data of an auction
   * @param  _auctionId Id of the auction
   * @return _auction Auction data struct
   */
  function auctions(uint256 _auctionId) external view returns (Auction memory _auction);

  /**
   * @notice Unpacked data of an auction
   * @param  _auctionId Id of the auction
   * @return _amountToSell How much collateral is sold in an auction [wad]
   * @return _amountToRaise Total/max amount of coins to raise [rad]
   * @return _initialTimestamp Time when the auction was created
   * @return _forgoneCollateralReceiver Who receives leftover collateral that is not sold in the auction (usually the liquidated SAFE)
   * @return _auctionIncomeRecipient Who receives the coins raised by the auction (usually the AccountingEngine)
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _auctions(uint256 _auctionId)
    external
    view
    returns (
      uint256 _amountToSell,
      uint256 _amountToRaise,
      uint256 _initialTimestamp,
      address _forgoneCollateralReceiver,
      address _auctionIncomeRecipient
    );

  /**
   * @notice Getter for the contract parameters struct
   * @return _cahParams Auction house parameters struct
   */
  function params() external view returns (CollateralAuctionHouseParams memory _cahParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _minimumBid Minimum acceptable bid [wad]
   * @return _minDiscount Minimum discount at which collateral is being sold [wad %]
   * @return _maxDiscount Maximum discount at which collateral is being sold [wad %]
   * @return _perSecondDiscountUpdateRate Rate at which the discount will be updated in an auction [ray]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (uint256 _minimumBid, uint256 _minDiscount, uint256 _maxDiscount, uint256 _perSecondDiscountUpdateRate);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  /// @notice Address of the LiquidationEngine contract
  function liquidationEngine() external view returns (ILiquidationEngine _liquidationEngine);

  /// @notice Address of the OracleRelayer contract
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);

  // --- Data ---

  /**
   * @notice The collateral type of the auctions created by this contract
   * @return _cType Bytes32 representation of the collateral type
   */
  function collateralType() external view returns (bytes32 _cType);

  /// @notice Total amount of collateral auctions created
  function auctionsStarted() external view returns (uint256 _auctionsStarted);

  // --- Getters ---

  /**
   * @notice Calculates the current discount of an auction
   * @param  _id Id of the auction
   * @return _auctionDiscount Current discount of the auction [wad %]
   */
  function getAuctionDiscount(uint256 _id) external view returns (uint256 _auctionDiscount);

  /**
   * @notice Calculates the amount of collateral that will be bought with a given bid
   * @param  _id Id of the auction
   * @param  _wad Bid amount [wad]
   * @return _collateralBought Amount of collateral that will be bought [wad]
   * @return _adjustedBid Adjusted bid amount [wad]
   */
  function getCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external view returns (uint256 _collateralBought, uint256 _adjustedBid);

  // --- Methods ---

  /**
   * @notice Buys collateral from an auction
   * @param  _id Id of the auction
   * @param  _wad Bid amount [wad]
   * @return _boughtCollateral Amount of collateral that was bought [wad]
   * @return _adjustedBid Adjusted bid amount [wad]
   */
  function buyCollateral(uint256 _id, uint256 _wad) external returns (uint256 _boughtCollateral, uint256 _adjustedBid);

  /**
   * @notice Starts a new collateral auction
   * @param  _forgoneCollateralReceiver Who receives leftover collateral that is not sold in the auction (usually the liquidated SAFE)
   * @param  _auctionIncomeRecipient Who receives the coins raised by the auction (usually the AccountingEngine)
   * @param  _amountToRaise Total/max amount of coins to raise [rad]
   * @param  _collateralToSell How much collateral is sold in an auction [wad]
   * @return _id Id of the started auction
   */
  function startAuction(
    address _forgoneCollateralReceiver,
    address _auctionIncomeRecipient,
    uint256 _amountToRaise,
    uint256 _collateralToSell
  ) external returns (uint256 _id);

  /**
   * @notice Terminates an auction prematurely
   * @dev    Transfers collateral and coins to the authorized caller address
   * @param  _auctionId Id of the auction
   */
  function terminateAuctionPrematurely(uint256 _auctionId) external;
}
