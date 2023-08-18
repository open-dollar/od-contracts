// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ICollateralAuctionHouse is IAuthorizable, IModifiable {
  // --- Events ---
  event StartAuction(
    uint256 indexed _id,
    address indexed _auctioneer,
    uint256 _blockTimestamp,
    uint256 _amountToSell,
    uint256 _amountToRaise
  );

  // NOTE: Doesn't have RestartAuction event

  event BuyCollateral(
    uint256 indexed _id, address _bidder, uint256 _blockTimestamp, uint256 _raisedAmount, uint256 _soldAmount
  );

  event SettleAuction(
    uint256 indexed _id, uint256 _blockTimestamp, address _leftoverReceiver, uint256 _leftoverCollateral
  );

  event TerminateAuctionPrematurely(
    uint256 indexed _id, uint256 _blockTimestamp, address _leftoverReceiver, uint256 _leftoverCollateral
  );

  // --- Errors ---
  error CAH_InvalidRedemptionPriceProvided();
  error CAH_NoCollateralForSale();
  error CAH_NothingToRaise();
  error CAH_DustyAuction();
  error CAH_InexistentAuction();
  error CAH_InvalidBid();
  error CAH_CollateralOracleInvalidValue();
  error CAH_NullBoughtAmount();
  error CAH_InvalidLeftToRaise();

  // --- Data ---
  struct CollateralAuctionHouseParams {
    // Minimum acceptable bid
    uint256 /* WAD */ minimumBid;
    // Minimum discount at which collateral is being sold
    uint256 /* WAD % */ minDiscount;
    // Maximum discount at which collateral is being sold
    uint256 /* WAD % */ maxDiscount;
    // Rate at which the discount will be updated in an auction
    uint256 perSecondDiscountUpdateRate;
  }

  struct Auction {
    // How much collateral is sold in an auction
    uint256 /* WAD */ amountToSell;
    // Total/max amount of coins to raise
    uint256 /* RAD */ amountToRaise;
    // Time when the auction was created
    uint256 /* timestamp */ initialTimestamp;
    // Who receives leftover collateral that is not sold in the auction (usually the liquidated SAFE)
    address forgoneCollateralReceiver;
    // Who receives the coins raised by the auction (usually the AccountingEngine)
    address auctionIncomeRecipient;
  }

  // solhint-disable-next-line func-name-mixedcase
  function AUCTION_HOUSE_TYPE() external view returns (bytes32 _auctionHouseType);

  function auctions(uint256 _auctionId) external view returns (Auction memory _auction);
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

  function params() external view returns (CollateralAuctionHouseParams memory _cahParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (uint256 _minimumBid, uint256 _minDiscount, uint256 _maxDiscount, uint256 _perSecondDiscountUpdateRate);

  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function liquidationEngine() external view returns (ILiquidationEngine _liquidationEngine);
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);
  function collateralType() external view returns (bytes32 _cType);

  function auctionsStarted() external view returns (uint256 _auctionsStarted);
  function getAuctionDiscount(uint256 _id) external view returns (uint256 _auctionDiscount);
  function bidAmount(uint256 _id) external view returns (uint256 _rad);
  function raisedAmount(uint256 _id) external view returns (uint256 _rad);
  function remainingAmountToSell(uint256 _id) external view returns (uint256 _wad);
  function forgoneCollateralReceiver(uint256 _id) external view returns (address _receiver);
  function amountToRaise(uint256 _id) external view returns (uint256 _rad);

  function getCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external view returns (uint256 _collateralBought, uint256 _adjustedBid);

  // --- Methods ---

  function buyCollateral(uint256 _id, uint256 _wad) external returns (uint256 _boughtCollateral, uint256 _adjustedBid);

  function startAuction(
    address _forgoneCollateralReceiver,
    address _initialBidder,
    uint256 /* RAD */ _amountToRaise,
    uint256 /* WAD */ _collateralToSell
  ) external returns (uint256 _id);

  function settleAuction(uint256 _id) external;

  function terminateAuctionPrematurely(uint256 _auctionId) external;
}
