// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

interface ICollateralAuctionHouse is IAuthorizable, IModifiable {
  // --- Events ---
  event StartAuction(
    uint256 _id,
    uint256 _auctionsStarted,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 indexed _amountToRaise,
    uint256 _startingDiscount,
    uint256 _maxDiscount,
    uint256 _perSecondDiscountUpdateRate,
    address indexed _forgoneCollateralReceiver,
    address indexed _auctionIncomeRecipient
  );
  event BuyCollateral(uint256 indexed _id, uint256 _wad, uint256 _boughtCollateral);
  event SettleAuction(uint256 indexed _id, uint256 _leftoverCollateral);
  event TerminateAuctionPrematurely(uint256 indexed _id, address _sender, uint256 _collateralAmount);

  // --- Errors ---
  error CAH_InvalidRedemptionPriceProvided();
  error CAH_NoCollateralForSale();
  error CAH_NothingToRaise();
  error CAH_DustyAuction();
  error CAH_InexistentAuction();
  error CAH_InvalidBid();
  error CAH_CollateralFSMInvalidValue();
  error CAH_NullBoughtAmount();
  error CAH_InvalidLeftToRaise();

  // --- Data ---
  struct CollateralAuctionHouseParams {
    // Minimum acceptable bid
    uint256 minimumBid; // [wad]
    // Minimum discount (compared to the system coin's current redemption price) at which collateral is being sold
    uint256 minDiscount;
    // Maximum discount (compared to the system coin's current redemption price) at which collateral is being sold
    uint256 maxDiscount;
    // Rate at which the discount will be updated in an auction
    uint256 perSecondDiscountUpdateRate;
    // Max lower bound deviation that the collateral market can have compared to the FSM price
    uint256 lowerCollateralDeviation;
    // Max upper bound deviation that the collateral market can have compared to the FSM price
    uint256 upperCollateralDeviation;
  }

  // NOTE: to be moved to CollateralAuctionHouseFactory
  struct CollateralAuctionHouseSystemCoinParams {
    // Min deviation for the system coin market result compared to the redemption price in order to take the market into account
    uint256 minSystemCoinDeviation;
    // Max lower bound deviation that the system coin oracle price feed can have compared to the systemCoinOracle price
    uint256 lowerSystemCoinDeviation;
    // Max upper bound deviation that the system coin oracle price feed can have compared to the systemCoinOracle price
    uint256 upperSystemCoinDeviation;
  }

  struct Auction {
    // How much collateral is sold in an auction
    uint256 amountToSell; // [wad]
    // Total/max amount of coins to raise
    uint256 amountToRaise; // [rad]
    // Current discount
    uint256 currentDiscount; // [wad]
    // Max possibe discount
    uint256 maxDiscount; // [wad]
    // Rate at which the discount is updated every second
    uint256 perSecondDiscountUpdateRate; // [ray]
    // Last time when the current discount was updated
    uint256 latestDiscountUpdateTime; // [unix timestamp]
    // Who (which SAFE) receives leftover collateral that is not sold in the auction; usually the liquidated SAFE
    address forgoneCollateralReceiver;
    // Who receives the coins raised by the auction; usually the accounting engine
    address auctionIncomeRecipient;
  }

  function auctions(uint256 _auctionId) external view returns (Auction memory _auction);
  // solhint-disable-next-line private-vars-leading-underscore
  function _auctions(uint256 _auctionId)
    external
    view
    returns (
      uint256 _amountToSell,
      uint256 _amountToRaise,
      uint256 _currentDiscount,
      uint256 _maxDiscount,
      uint256 _perSecondDiscountUpdateRate,
      uint256 _latestDiscountUpdateTime,
      address _forgoneCollateralReceiver,
      address _auctionIncomeRecipient
    );

  function params() external view returns (CollateralAuctionHouseSystemCoinParams memory _cahParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (uint256 _minSystemCoinDeviation, uint256 _lowerSystemCoinDeviation, uint256 _upperSystemCoinDeviation);

  function cParams() external view returns (CollateralAuctionHouseParams memory _cahCParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams()
    external
    view
    returns (
      uint256 _minimumBid,
      uint256 _minDiscount,
      uint256 _maxDiscount,
      uint256 _perSecondDiscountUpdateRate,
      uint256 _lowerCollateralDeviation,
      uint256 _upperCollateralDeviation
    );

  function getApproximateCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external view returns (uint256 _collateralFsmPriceFeedValue, uint256 _systemCoinPriceFeedValue);

  function getCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external returns (uint256 _collateralFsmPriceFeedValue, uint256 _systemCoinPriceFeedValue);
  function buyCollateral(uint256 _id, uint256 _wad) external;

  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  function liquidationEngine() external view returns (ILiquidationEngine _liquidationEngine);

  function collateralType() external view returns (bytes32 _cType);

  function getDiscountedCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _customDiscount
  ) external view returns (uint256 _discountedCollateralPrice);

  function getCollateralMarketPrice() external view returns (uint256 _priceFeed);

  function getSystemCoinMarketPrice() external view returns (uint256 _priceFeed);

  function getSystemCoinFloorDeviatedPrice(uint256 _redemptionPrice) external view returns (uint256 _floorPrice);

  function getSystemCoinCeilingDeviatedPrice(uint256 _redemptionPrice) external view returns (uint256 _ceilingPrice);

  function getFinalSystemCoinPrice(
    uint256 _systemCoinRedemptionPrice,
    uint256 _systemCoinMarketPrice
  ) external view returns (uint256 _finalSystemCoinPrice);

  function getFinalBaseCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue
  ) external view returns (uint256 _adjustedMarketPrice);

  function getNextCurrentDiscount(uint256 _id) external view returns (uint256 _nextDiscount);

  function getAdjustedBid(uint256 _id, uint256 _wad) external view returns (bool _valid, uint256 _adjustedBid);

  function startAuction(
    address _forgoneCollateralReceiver,
    address _initialBidder,
    uint256 /* RAD */ _amountToRaise,
    uint256 /* WAD */ _collateralToSell,
    uint256 /* RAD */ _initialBid
  ) external returns (uint256 _id);
  function settleAuction(uint256 _id) external;

  function getCollateralFSMAndFinalSystemCoinPrices(uint256 _systemCoinRedemptionPrice)
    external
    view
    returns (uint256 _cFsmPriceFeedValue, uint256 _sCoinAdjustedPrice);

  function auctionsStarted() external view returns (uint256 _auctionsStarted);

  function lastReadRedemptionPrice() external view returns (uint256 _lastReadRedemptionPrice);

  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);

  function bidAmount(uint256 _id) external view returns (uint256 _rad);
  function raisedAmount(uint256 _id) external view returns (uint256 _rad);
  function remainingAmountToSell(uint256 _id) external view returns (uint256 _wad);
  function forgoneCollateralReceiver(uint256 _id) external view returns (address _receiver);
  function amountToRaise(uint256 _id) external view returns (uint256 _rad);
  function terminateAuctionPrematurely(uint256 _auctionId) external;
}
