// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

interface IIncreasingDiscountCollateralAuctionHouse is ICollateralAuctionHouse {
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
    uint48 _discountIncreaseDeadline,
    address indexed _forgoneCollateralReceiver,
    address indexed _auctionIncomeRecipient
  );
  event ModifyParameters(bytes32 _parameter, uint256 _data);
  event ModifyParameters(bytes32 _parameter, address _data);
  event BuyCollateral(uint256 indexed _id, uint256 _wad, uint256 _boughtCollateral);
  event SettleAuction(uint256 indexed _id, uint256 _leftoverCollateral);
  event TerminateAuctionPrematurely(uint256 indexed _id, address _sender, uint256 _collateralAmount);

  // --- Data ---
  struct Bid {
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
    // Deadline after which the discount cannot increase anymore
    uint48 discountIncreaseDeadline; // [unix epoch time]
    // Who (which SAFE) receives leftover collateral that is not sold in the auction; usually the liquidated SAFE
    address forgoneCollateralReceiver;
    // Who receives the coins raised by the auction; usually the accounting engine
    address auctionIncomeRecipient;
  }

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

  function collateralType() external view returns (bytes32 _collateralType);

  function bids(uint256 _id) external view returns (Bid memory _bid);

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
    address _auctionIncomeRecipient,
    uint256 _amountToRaise,
    uint256 _amountToSell,
    uint256 _initialBid // NOTE: ignored, only used in event
  ) external returns (uint256 _id);

  function getCollateralFSMAndFinalSystemCoinPrices(uint256 _systemCoinRedemptionPrice)
    external
    view
    returns (uint256 _cFsmPriceFeedValue, uint256 _sCoinAdjustedPrice);

  function collateralFSM() external view returns (IDelayedOracle _collateralFSM);

  function minSystemCoinMarketDeviation() external view returns (uint256 _minSystemCoinMarketDeviation); // [wad]

  function upperSystemCoinMarketDeviation() external view returns (uint256 _upperSystemCoinMarketDeviation); // [wad]

  function lowerSystemCoinMarketDeviation() external view returns (uint256 _lowerSystemCoinMarketDeviation); // [wad]

  function upperCollateralMarketDeviation() external view returns (uint256 _upperCollateralMarketDeviation); // [wad]

  function lowerCollateralMarketDeviation() external view returns (uint256 _lowerCollateralMarketDeviation); // [wad]

  function minimumBid() external view returns (uint256 _minimumBid); // [wad]

  function minDiscount() external view returns (uint256 _minDiscount); // [wad]

  function maxDiscount() external view returns (uint256 _maxDiscount); // [wad]

  function perSecondDiscountUpdateRate() external view returns (uint256 _perSecondDiscountUpdateRate); // [ray]

  function auctionsStarted() external view returns (uint256 _auctionsStarted);

  function maxDiscountUpdateRateTimeline() external view returns (uint256 _maxDiscountUpdateRateTimeline); // [seconds]

  function lastReadRedemptionPrice() external view returns (uint256 _lastReadRedemptionPrice);
}
