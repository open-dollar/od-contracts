// SPDX-License-Identifier: GPL-3.0
/// IncreasingDiscountCollateralAuctionHouse.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer as OracleRelayerLike} from '@interfaces/IOracleRelayer.sol';
import {IBaseOracle as OracleLike} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {ILiquidationEngine as LiquidationEngineLike} from '@interfaces/ILiquidationEngine.sol';
import {IIncreasingDiscountCollateralAuctionHouse} from '@interfaces/IIncreasingDiscountCollateralAuctionHouse.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';

/*
   This thing lets you sell some collateral at an increasing discount in order to instantly recapitalize the system
*/
contract IncreasingDiscountCollateralAuctionHouse is Authorizable, IIncreasingDiscountCollateralAuctionHouse {
  using Math for uint256;

  // Bid data for each separate auction
  mapping(uint256 => Bid) internal _bids;

  // SAFE database
  SAFEEngineLike public safeEngine;
  // Collateral type name
  bytes32 public collateralType;

  // Minimum acceptable bid
  uint256 public minimumBid = 5 * WAD; // [wad]
  // Total length of the auction. Kept to adhere to the same interface as the English auction but redundant
  uint48 public totalAuctionLength = type(uint48).max; // [seconds]
  // Number of auctions started up until now
  uint256 public auctionsStarted = 0;
  // The last read redemption price
  uint256 public lastReadRedemptionPrice;
  // Minimum discount (compared to the system coin's current redemption price) at which collateral is being sold
  uint256 public minDiscount = 0.95e18; // 5% discount                                      // [wad]
  // Maximum discount (compared to the system coin's current redemption price) at which collateral is being sold
  uint256 public maxDiscount = 0.95e18; // 5% discount                                      // [wad]
  // Rate at which the discount will be updated in an auction
  uint256 public perSecondDiscountUpdateRate = RAY; // [ray]
  // Max time over which the discount can be updated
  uint256 public maxDiscountUpdateRateTimeline = 1 hours; // [seconds]
  // Max lower bound deviation that the collateral market can have compared to the FSM price
  uint256 public lowerCollateralMarketDeviation = 0.9e18; // 10% deviation                                    // [wad]
  // Max upper bound deviation that the collateral market can have compared to the FSM price
  uint256 public upperCollateralMarketDeviation = 0.95e18; // 5% deviation                                     // [wad]
  // Max lower bound deviation that the system coin oracle price feed can have compared to the systemCoinOracle price
  uint256 public lowerSystemCoinMarketDeviation = WAD; // 0% deviation                                     // [wad]
  // Max upper bound deviation that the system coin oracle price feed can have compared to the systemCoinOracle price
  uint256 public upperSystemCoinMarketDeviation = WAD; // 0% deviation                                     // [wad]
  // Min deviation for the system coin market result compared to the redemption price in order to take the market into account
  uint256 public minSystemCoinMarketDeviation = 0.999e18; // [wad]

  OracleRelayerLike public oracleRelayer;
  IDelayedOracle public collateralFSM;
  OracleLike public systemCoinOracle;
  LiquidationEngineLike public liquidationEngine;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('COLLATERAL');
  bytes32 public constant AUCTION_TYPE = bytes32('INCREASING_DISCOUNT');

  // --- Init ---
  constructor(address _safeEngine, address _liquidationEngine, bytes32 _collateralType) Authorizable(msg.sender) {
    safeEngine = SAFEEngineLike(_safeEngine);
    liquidationEngine = LiquidationEngineLike(_liquidationEngine);
    collateralType = _collateralType;
  }

  // --- Admin ---
  /**
   * @notice Modify an uint256 parameter
   * @param _parameter The name of the parameter to modify
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _parameter, uint256 _data) external isAuthorized {
    if (_parameter == 'minDiscount') {
      require(_data >= maxDiscount && _data < WAD, 'IncreasingDiscountCollateralAuctionHouse/invalid-min-discount');
      minDiscount = _data;
    } else if (_parameter == 'maxDiscount') {
      require(
        (_data <= minDiscount && _data < WAD) && _data > 0,
        'IncreasingDiscountCollateralAuctionHouse/invalid-max-discount'
      );
      maxDiscount = _data;
    } else if (_parameter == 'perSecondDiscountUpdateRate') {
      require(_data <= RAY, 'IncreasingDiscountCollateralAuctionHouse/invalid-discount-update-rate');
      perSecondDiscountUpdateRate = _data;
    } else if (_parameter == 'maxDiscountUpdateRateTimeline') {
      require(
        _data > 0 && uint256(type(uint48).max) > block.timestamp + _data,
        'IncreasingDiscountCollateralAuctionHouse/invalid-update-rate-time'
      );
      maxDiscountUpdateRateTimeline = _data;
    } else if (_parameter == 'lowerCollateralMarketDeviation') {
      require(_data <= WAD, 'IncreasingDiscountCollateralAuctionHouse/invalid-lower-collateral-market-deviation');
      lowerCollateralMarketDeviation = _data;
    } else if (_parameter == 'upperCollateralMarketDeviation') {
      require(_data <= WAD, 'IncreasingDiscountCollateralAuctionHouse/invalid-upper-collateral-market-deviation');
      upperCollateralMarketDeviation = _data;
    } else if (_parameter == 'lowerSystemCoinMarketDeviation') {
      require(_data <= WAD, 'IncreasingDiscountCollateralAuctionHouse/invalid-lower-system-coin-market-deviation');
      lowerSystemCoinMarketDeviation = _data;
    } else if (_parameter == 'upperSystemCoinMarketDeviation') {
      require(_data <= WAD, 'IncreasingDiscountCollateralAuctionHouse/invalid-upper-system-coin-market-deviation');
      upperSystemCoinMarketDeviation = _data;
    } else if (_parameter == 'minSystemCoinMarketDeviation') {
      minSystemCoinMarketDeviation = _data;
    } else if (_parameter == 'minimumBid') {
      minimumBid = _data;
    } else {
      revert('IncreasingDiscountCollateralAuctionHouse/modify-unrecognized-param');
    }
    emit ModifyParameters(_parameter, _data);
  }

  /**
   * @notice Modify an addres parameter
   * @param _parameter The parameter name
   * @param _data New address for the parameter
   */
  function modifyParameters(bytes32 _parameter, address _data) external isAuthorized {
    if (_parameter == 'oracleRelayer') {
      oracleRelayer = OracleRelayerLike(_data);
    } else if (_parameter == 'collateralFSM') {
      collateralFSM = IDelayedOracle(_data);
      // Check that priceSource() is implemented
      collateralFSM.priceSource();
    } else if (_parameter == 'systemCoinOracle') {
      systemCoinOracle = OracleLike(_data);
    } else if (_parameter == 'liquidationEngine') {
      liquidationEngine = LiquidationEngineLike(_data);
    } else {
      revert('IncreasingDiscountCollateralAuctionHouse/modify-unrecognized-param');
    }
    emit ModifyParameters(_parameter, _data);
  }

  function bids(uint256 _auctionId) external view returns (Bid memory) {
    return _bids[_auctionId];
  }

  // --- Private Auction Utils ---
  /**
   * @notice Get the amount of bought collateral from a specific auction using custom collateral price feeds, a system
   *         coin price feed and a custom discount
   * @param  _id The ID of the auction to bid in and get collateral from
   * @param  _collateralFsmPriceFeedValue The collateral price fetched from the FSM
   * @param  _collateralMarketPriceFeedValue The collateral price fetched from the oracle market
   * @param  _systemCoinPriceFeedValue The system coin market price fetched from the oracle
   * @param  _adjustedBid The system coin bid
   * @param  _customDiscount The discount offered
   * @return _boughtCollateral Amount of collateral bought for given parameters
   */
  function _getBoughtCollateral(
    uint256 _id,
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _adjustedBid,
    uint256 _customDiscount
  ) internal view virtual returns (uint256 _boughtCollateral) {
    // calculate the collateral price in relation to the latest system coin price and apply the discount
    uint256 _discountedCollateralPrice = _getDiscountedCollateralPrice(
      _collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue, _systemCoinPriceFeedValue, _customDiscount
    );
    // calculate the amount of collateral bought
    _boughtCollateral = _adjustedBid.wdiv(_discountedCollateralPrice);
    // if the calculated collateral amount exceeds the amount still up for sale, adjust it to the remaining amount
    _boughtCollateral = _boughtCollateral > _bids[_id].amountToSell ? _bids[_id].amountToSell : _boughtCollateral;
  }

  /**
   * @notice Update the discount used in a particular auction
   * @param _id The id of the auction to update the discount for
   * @return _updatedDiscount The newly computed currentDiscount for the targeted auction
   */
  function _updateCurrentDiscount(uint256 _id) internal virtual returns (uint256 _updatedDiscount) {
    // Work directly with storage
    Bid storage auctionBidData = _bids[_id];
    auctionBidData.currentDiscount = _getNextCurrentDiscount(_id);
    auctionBidData.latestDiscountUpdateTime = block.timestamp;
    _updatedDiscount = auctionBidData.currentDiscount;
  }

  // --- Public Auction Utils ---
  /**
   * @notice Fetch the collateral market price (from the oracle, not FSM)
   * @return _priceFeed The collateral price from the oracle market; zero if the address of the collateralMedian (as fetched from the FSM) is null
   */
  function getCollateralMarketPrice() external view returns (uint256 _priceFeed) {
    return _getCollateralMarketPrice();
  }

  function _getCollateralMarketPrice() internal view virtual returns (uint256 _priceFeed) {
    // Fetch the collateral market address from the collateral FSM
    OracleLike _marketOracle;
    try collateralFSM.priceSource() returns (OracleLike __marketOracle) {
      _marketOracle = __marketOracle;
    } catch (bytes memory) {}

    if (address(_marketOracle) == address(0)) return 0;

    // wrapped call toward the collateral market
    try _marketOracle.getResultWithValidity() returns (uint256 _price, bool _valid) {
      if (_valid) {
        _priceFeed = _price;
      }
    } catch (bytes memory) {
      return 0;
    }
  }

  /**
   * @notice Fetch the system coin market price
   * @return _priceFeed The system coin market price fetch from the oracle
   */
  function getSystemCoinMarketPrice() external view returns (uint256 _priceFeed) {
    return _getSystemCoinMarketPrice();
  }

  function _getSystemCoinMarketPrice() internal view virtual returns (uint256 _priceFeed) {
    if (address(systemCoinOracle) == address(0)) return 0;

    // wrapped call toward the system coin oracle
    try systemCoinOracle.getResultWithValidity() returns (uint256 _price, bool _valid) {
      if (_valid) {
        _priceFeed = uint256(_price) * 10 ** 9; // scale to RAY
      }
    } catch (bytes memory) {
      return 0;
    }
  }

  /**
   * @notice Get the smallest possible price that's at max lowerSystemCoinMarketDeviation deviated from the redemption price and at least
   *         minSystemCoinMarketDeviation deviated
   */
  function getSystemCoinFloorDeviatedPrice(uint256 _redemptionPrice) external view returns (uint256 _floorPrice) {
    return _getSystemCoinFloorDeviatedPrice(_redemptionPrice);
  }

  function _getSystemCoinFloorDeviatedPrice(uint256 _redemptionPrice)
    internal
    view
    virtual
    returns (uint256 _floorPrice)
  {
    uint256 minFloorDeviatedPrice = _redemptionPrice.wmul(minSystemCoinMarketDeviation);
    _floorPrice = _redemptionPrice.wmul(lowerSystemCoinMarketDeviation);
    _floorPrice = _floorPrice <= minFloorDeviatedPrice ? _floorPrice : _redemptionPrice;
  }

  /**
   * @notice Get the highest possible price that's at max upperSystemCoinMarketDeviation deviated from the redemption price and at least
   *         minSystemCoinMarketDeviation deviated
   */
  function getSystemCoinCeilingDeviatedPrice(uint256 _redemptionPrice) external view returns (uint256 _ceilingPrice) {
    return _getSystemCoinCeilingDeviatedPrice(_redemptionPrice);
  }

  function _getSystemCoinCeilingDeviatedPrice(uint256 _redemptionPrice)
    internal
    view
    virtual
    returns (uint256 _ceilingPrice)
  {
    uint256 minCeilingDeviatedPrice = _redemptionPrice.wmul(2 * WAD - minSystemCoinMarketDeviation);
    _ceilingPrice = _redemptionPrice.wmul(2 * WAD - upperSystemCoinMarketDeviation);
    _ceilingPrice = _ceilingPrice >= minCeilingDeviatedPrice ? _ceilingPrice : _redemptionPrice;
  }

  /**
   * @notice Get the collateral price from the FSM and the final system coin price that will be used when bidding in an auction
   * @param _systemCoinRedemptionPrice The system coin redemption price
   * @return _cFsmPriceFeedValue The collateral price from the FSM and the final system coin price used for bidding (picking between redemption and market prices)
   * @return _sCoinAdjustedPrice The final system coin price used for bidding (picking between redemption and market prices)
   */
  function getCollateralFSMAndFinalSystemCoinPrices(uint256 _systemCoinRedemptionPrice)
    external
    view
    returns (uint256 _cFsmPriceFeedValue, uint256 _sCoinAdjustedPrice)
  {
    return _getCollateralFSMAndFinalSystemCoinPrices(_systemCoinRedemptionPrice);
  }

  function _getCollateralFSMAndFinalSystemCoinPrices(uint256 _systemCoinRedemptionPrice)
    internal
    view
    virtual
    returns (uint256 _cFsmPriceFeedValue, uint256 _sCoinAdjustedPrice)
  {
    require(
      _systemCoinRedemptionPrice > 0, 'IncreasingDiscountCollateralAuctionHouse/invalid-redemption-price-provided'
    );
    (uint256 _collateralFsmPriceFeedValue, bool _collateralFsmHasValidValue) = collateralFSM.getResultWithValidity();
    if (!_collateralFsmHasValidValue) {
      return (0, 0);
    }

    uint256 _systemCoinAdjustedPrice = _systemCoinRedemptionPrice;
    uint256 _systemCoinPriceFeedValue = _getSystemCoinMarketPrice();

    if (_systemCoinPriceFeedValue > 0) {
      _systemCoinAdjustedPrice = _getFinalSystemCoinPrice(_systemCoinRedemptionPrice, _systemCoinPriceFeedValue);
    }

    return (_collateralFsmPriceFeedValue, _systemCoinAdjustedPrice);
  }

  function getFinalSystemCoinPrice(
    uint256 _systemCoinRedemptionPrice,
    uint256 _systemCoinMarketPrice
  ) external view returns (uint256 _finalSystemCoinPrice) {
    return _getFinalSystemCoinPrice(_systemCoinRedemptionPrice, _systemCoinMarketPrice);
  }

  function _getFinalSystemCoinPrice(
    uint256 _systemCoinRedemptionPrice,
    uint256 _systemCoinMarketPrice
  ) internal view virtual returns (uint256 _finalSystemCoinPrice) {
    uint256 _floorPrice = _getSystemCoinFloorDeviatedPrice(_systemCoinRedemptionPrice);
    uint256 _ceilingPrice = _getSystemCoinCeilingDeviatedPrice(_systemCoinRedemptionPrice);

    if (_systemCoinMarketPrice < _systemCoinRedemptionPrice) {
      _finalSystemCoinPrice = Math.max(_systemCoinMarketPrice, _floorPrice);
    } else {
      _finalSystemCoinPrice = Math.min(_systemCoinMarketPrice, _ceilingPrice);
    }
  }

  /**
   * @notice Get the collateral price used in bidding by picking between the raw FSM and the oracle market price and taking into account
   *         deviation limits
   * @param _collateralFsmPriceFeedValue The collateral price fetched from the FSM
   * @param _collateralMarketPriceFeedValue The collateral price fetched from the market attached to the FSM
   * @return _adjustedMarketPrice The final collateral price used for bidding
   */
  function getFinalBaseCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue
  ) external view returns (uint256 _adjustedMarketPrice) {
    return _getFinalBaseCollateralPrice(_collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue);
  }

  function _getFinalBaseCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue
  ) internal view virtual returns (uint256 _adjustedMarketPrice) {
    uint256 floorPrice = _collateralFsmPriceFeedValue.wmul(lowerCollateralMarketDeviation);
    uint256 ceilingPrice = _collateralFsmPriceFeedValue.wmul(2 * WAD - upperCollateralMarketDeviation);

    _adjustedMarketPrice =
      (_collateralMarketPriceFeedValue == 0) ? _collateralFsmPriceFeedValue : _collateralMarketPriceFeedValue;

    if (_adjustedMarketPrice < _collateralFsmPriceFeedValue) {
      _adjustedMarketPrice = Math.max(_adjustedMarketPrice, floorPrice);
    } else {
      _adjustedMarketPrice = Math.min(_adjustedMarketPrice, ceilingPrice);
    }
  }

  /**
   * @notice Get the discounted collateral price (using a custom discount)
   * @param _collateralFsmPriceFeedValue The collateral price fetched from the FSM
   * @param _collateralMarketPriceFeedValue The collateral price fetched from the oracle market
   * @param _systemCoinPriceFeedValue The system coin price fetched from the oracle
   * @param _customDiscount The custom discount used to calculate the collateral price offered
   * @return _discountedCollateralPrice The discounted collateral price
   */
  function getDiscountedCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _customDiscount
  ) external view returns (uint256 _discountedCollateralPrice) {
    return _getDiscountedCollateralPrice(
      _collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue, _systemCoinPriceFeedValue, _customDiscount
    );
  }

  function _getDiscountedCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _customDiscount
  ) internal view virtual returns (uint256 _discountedCollateralPrice) {
    // calculate the collateral price in relation to the latest system coin price and apply the discount
    _discountedCollateralPrice = _getFinalBaseCollateralPrice(
      _collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue
    ).rdiv(_systemCoinPriceFeedValue).wmul(_customDiscount);
  }

  /**
   * @notice Get the upcoming discount that will be used in a specific auction
   * @param _id The ID of the auction to calculate the upcoming discount for
   * @return _nextDiscount The upcoming discount that will be used in the targeted auction
   */
  function getNextCurrentDiscount(uint256 _id) external view returns (uint256 _nextDiscount) {
    return _getNextCurrentDiscount(_id);
  }

  function _getNextCurrentDiscount(uint256 _id) internal view virtual returns (uint256 _nextDiscount) {
    if (_bids[_id].forgoneCollateralReceiver == address(0)) return RAY;
    _nextDiscount = _bids[_id].currentDiscount;

    // If the increase deadline hasn't been passed yet and the current discount is not at or greater than max
    if (block.timestamp < _bids[_id].discountIncreaseDeadline && _bids[_id].currentDiscount > _bids[_id].maxDiscount) {
      // Calculate the new current discount
      _nextDiscount = _bids[_id].perSecondDiscountUpdateRate.rpow(block.timestamp - _bids[_id].latestDiscountUpdateTime)
        .rmul(_bids[_id].currentDiscount);

      // If the new discount is greater than the max one
      if (_nextDiscount <= _bids[_id].maxDiscount) {
        _nextDiscount = _bids[_id].maxDiscount;
      }
    } else {
      // Determine the conditions when we can instantly set the current discount to max
      bool _currentZeroMaxNonZero = _bids[_id].currentDiscount == 0 && _bids[_id].maxDiscount > 0;
      bool _doneUpdating = uint48(block.timestamp) >= _bids[_id].discountIncreaseDeadline
        && _bids[_id].currentDiscount != _bids[_id].maxDiscount;

      if (_currentZeroMaxNonZero || _doneUpdating) {
        _nextDiscount = _bids[_id].maxDiscount;
      }
    }
  }

  /**
   * @notice Get the actual bid that will be used in an auction (taking into account the bidder input)
   * @param _id The id of the auction to calculate the adjusted bid for
   * @param _wad The initial bid submitted
   * @return _valid Whether the bid is valid or not and the adjusted bid
   * @return _adjustedBid The adjusted bid
   */
  function getAdjustedBid(uint256 _id, uint256 _wad) external view returns (bool _valid, uint256 _adjustedBid) {
    return _getAdjustedBid(_id, _wad);
  }

  function _getAdjustedBid(uint256 _id, uint256 _wad) internal view virtual returns (bool _valid, uint256 _adjustedBid) {
    if (_bids[_id].amountToSell == 0 || _bids[_id].amountToRaise == 0 || _wad == 0 || _wad < minimumBid) {
      return (false, _wad);
    }

    uint256 remainingToRaise = _bids[_id].amountToRaise;

    // bound max amount offered in exchange for collateral
    _adjustedBid = _wad;
    if (_adjustedBid * RAY > remainingToRaise) {
      _adjustedBid = (remainingToRaise / RAY) + 1;
    }

    remainingToRaise = _adjustedBid * RAY > remainingToRaise ? 0 : _bids[_id].amountToRaise - _adjustedBid * RAY;
    _valid = remainingToRaise == 0 || remainingToRaise >= RAY;
  }

  // --- Core Auction Logic ---
  /**
   * @notice Start a new collateral auction
   * @param _forgoneCollateralReceiver Who receives leftover collateral that is not auctioned
   * @param _auctionIncomeRecipient Who receives the amount raised in the auction
   * @param _amountToRaise Total amount of coins to raise (rad)
   * @param _amountToSell Total amount of collateral available to sell (wad)
   * @param _initialBid Unused
   */
  function startAuction(
    address _forgoneCollateralReceiver,
    address _auctionIncomeRecipient,
    uint256 _amountToRaise,
    uint256 _amountToSell,
    uint256 _initialBid // NOTE: ignored, only used in event
  ) external isAuthorized returns (uint256 _id) {
    return
      _startAuction(_forgoneCollateralReceiver, _auctionIncomeRecipient, _amountToRaise, _amountToSell, _initialBid);
  }

  function _startAuction(
    address _forgoneCollateralReceiver,
    address _auctionIncomeRecipient,
    uint256 _amountToRaise,
    uint256 _amountToSell,
    uint256 _initialBid // NOTE: ignored, only used in event
  ) internal virtual isAuthorized returns (uint256 _id) {
    require(_amountToSell > 0, 'IncreasingDiscountCollateralAuctionHouse/no-collateral-for-sale');
    require(_amountToRaise > 0, 'IncreasingDiscountCollateralAuctionHouse/nothing-to-raise');
    require(_amountToRaise >= RAY, 'IncreasingDiscountCollateralAuctionHouse/dusty-auction');
    _id = ++auctionsStarted;

    uint48 _discountIncreaseDeadline = uint48(block.timestamp) + uint48(maxDiscountUpdateRateTimeline);

    _bids[_id].currentDiscount = minDiscount;
    _bids[_id].maxDiscount = maxDiscount;
    _bids[_id].perSecondDiscountUpdateRate = perSecondDiscountUpdateRate;
    _bids[_id].discountIncreaseDeadline = _discountIncreaseDeadline;
    _bids[_id].latestDiscountUpdateTime = block.timestamp;
    _bids[_id].amountToSell = _amountToSell;
    _bids[_id].forgoneCollateralReceiver = _forgoneCollateralReceiver;
    _bids[_id].auctionIncomeRecipient = _auctionIncomeRecipient;
    _bids[_id].amountToRaise = _amountToRaise;

    safeEngine.transferCollateral(collateralType, msg.sender, address(this), _amountToSell);

    emit StartAuction(
      _id,
      auctionsStarted, // NOTE: redundant
      _amountToSell,
      _initialBid,
      _amountToRaise,
      minDiscount,
      maxDiscount,
      perSecondDiscountUpdateRate,
      _discountIncreaseDeadline,
      _forgoneCollateralReceiver,
      _auctionIncomeRecipient
    );
  }

  /**
   * @notice Calculate how much collateral someone would buy from an auction using the last read redemption price and the old current
   *         discount associated with the auction
   * @param _id ID of the auction to buy collateral from
   * @param _wad New bid submitted
   */
  function getApproximateCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external view returns (uint256 _boughtCollateral, uint256 _adjustedBid) {
    if (lastReadRedemptionPrice == 0) return (0, _wad);

    bool _validAuctionAndBid;
    (_validAuctionAndBid, _adjustedBid) = _getAdjustedBid(_id, _wad);
    if (!_validAuctionAndBid) {
      return (0, _adjustedBid);
    }

    // check that the oracle doesn't return an invalid value
    (uint256 _collateralFsmPriceFeedValue, uint256 _systemCoinPriceFeedValue) =
      _getCollateralFSMAndFinalSystemCoinPrices(lastReadRedemptionPrice);
    if (_collateralFsmPriceFeedValue == 0) {
      return (0, _adjustedBid);
    }

    _boughtCollateral = _getBoughtCollateral(
      _id,
      _collateralFsmPriceFeedValue,
      _getCollateralMarketPrice(),
      _systemCoinPriceFeedValue,
      _adjustedBid,
      _bids[_id].currentDiscount
    );
  }

  function _getCollateralBought(
    uint256 _id,
    uint256 _wad
  ) internal virtual returns (uint256 _boughtCollateral, uint256 _adjustedBid) {
    bool _validAuctionAndBid;
    (_validAuctionAndBid, _adjustedBid) = _getAdjustedBid(_id, _wad);
    if (!_validAuctionAndBid) {
      return (0, _adjustedBid);
    }

    // Read the redemption price
    lastReadRedemptionPrice = oracleRelayer.redemptionPrice();

    // check that the oracle doesn't return an invalid value
    (uint256 _collateralFsmPriceFeedValue, uint256 _systemCoinPriceFeedValue) =
      _getCollateralFSMAndFinalSystemCoinPrices(lastReadRedemptionPrice);
    if (_collateralFsmPriceFeedValue == 0) {
      return (0, _adjustedBid);
    }

    _boughtCollateral = _getBoughtCollateral(
      _id,
      _collateralFsmPriceFeedValue,
      _getCollateralMarketPrice(),
      _systemCoinPriceFeedValue,
      _adjustedBid,
      _updateCurrentDiscount(_id)
    );
  }

  /**
   * @notice Calculate how much collateral someone would buy from an auction using the latest redemption price fetched from the
   *         OracleRelayer and the latest updated discount associated with the auction
   * @param  _id ID of the auction to buy collateral from
   * @param  _wad New bid submitted
   */
  function getCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external returns (uint256 _boughtCollateral, uint256 _adjustedBid) {
    return _getCollateralBought(_id, _wad);
  }

  /**
   * @notice Buy collateral from an auction at an increasing discount
   * @param _id ID of the auction to buy collateral from
   * @param _wad New bid submitted (as a WAD which has 18 decimals)
   */
  function buyCollateral(uint256 _id, uint256 _wad) external {
    require(
      _bids[_id].amountToSell > 0 && _bids[_id].amountToRaise > 0,
      'IncreasingDiscountCollateralAuctionHouse/inexistent-auction'
    );
    require(_wad > 0 && _wad >= minimumBid, 'IncreasingDiscountCollateralAuctionHouse/invalid-bid');

    // bound max amount offered in exchange for collateral (in case someone offers more than it's necessary)
    uint256 _adjustedBid = _wad;
    if (_adjustedBid * RAY > _bids[_id].amountToRaise) {
      _adjustedBid = _bids[_id].amountToRaise / RAY + 1;
    }

    // Read the redemption price
    lastReadRedemptionPrice = oracleRelayer.redemptionPrice();

    // check that the collateral FSM doesn't return an invalid value
    (uint256 collateralFsmPriceFeedValue, uint256 systemCoinPriceFeedValue) =
      _getCollateralFSMAndFinalSystemCoinPrices(lastReadRedemptionPrice);
    require(collateralFsmPriceFeedValue > 0, 'IncreasingDiscountCollateralAuctionHouse/collateral-fsm-invalid-value');

    // get the amount of collateral bought
    uint256 _boughtCollateral = _getBoughtCollateral(
      _id,
      collateralFsmPriceFeedValue,
      _getCollateralMarketPrice(),
      systemCoinPriceFeedValue,
      _adjustedBid,
      _updateCurrentDiscount(_id)
    );
    // check that the calculated amount is greater than zero
    require(_boughtCollateral > 0, 'IncreasingDiscountCollateralAuctionHouse/null-bought-amount');
    // update the amount of collateral to sell
    _bids[_id].amountToSell = _bids[_id].amountToSell - _boughtCollateral;

    // update remainingToRaise in case amountToSell is zero (everything has been sold)
    uint256 _remainingToRaise = _wad * RAY >= _bids[_id].amountToRaise || _bids[_id].amountToSell == 0
      ? _bids[_id].amountToRaise
      : _bids[_id].amountToRaise - (_wad * RAY);

    // update leftover amount to raise in the bid struct
    _bids[_id].amountToRaise =
      _adjustedBid * RAY > _bids[_id].amountToRaise ? 0 : _bids[_id].amountToRaise - _adjustedBid * RAY;

    // check that the remaining amount to raise is either zero or higher than RAY
    require(
      _bids[_id].amountToRaise == 0 || _bids[_id].amountToRaise >= RAY,
      'IncreasingDiscountCollateralAuctionHouse/invalid-left-to-raise'
    );

    // transfer the bid to the income recipient and the collateral to the bidder
    safeEngine.transferInternalCoins(msg.sender, _bids[_id].auctionIncomeRecipient, _adjustedBid * RAY);
    safeEngine.transferCollateral(collateralType, address(this), msg.sender, _boughtCollateral);

    // Emit the buy event
    emit BuyCollateral(_id, _adjustedBid, _boughtCollateral);

    // Remove coins from the liquidation buffer
    bool _soldAll = _bids[_id].amountToRaise == 0 || _bids[_id].amountToSell == 0;
    if (_soldAll) {
      liquidationEngine.removeCoinsFromAuction(_remainingToRaise);
    } else {
      liquidationEngine.removeCoinsFromAuction(_adjustedBid * RAY);
    }

    // If the auction raised the whole amount or all collateral was sold,
    // send remaining collateral to the forgone receiver
    if (_soldAll) {
      safeEngine.transferCollateral(
        collateralType, address(this), _bids[_id].forgoneCollateralReceiver, _bids[_id].amountToSell
      );
      delete _bids[_id];
      emit SettleAuction(_id, _bids[_id].amountToSell);
    }
  }

  /**
   * @notice Settle/finish an auction
   * @dev Deprecated
   */
  function settleAuction(uint256) external pure {
    return;
  }

  /**
   * @notice Terminate an auction prematurely. Usually called by Global Settlement.
   * @param _id ID of the auction to settle
   */
  function terminateAuctionPrematurely(uint256 _id) external isAuthorized {
    require(
      _bids[_id].amountToSell > 0 && _bids[_id].amountToRaise > 0,
      'IncreasingDiscountCollateralAuctionHouse/inexistent-auction'
    );
    liquidationEngine.removeCoinsFromAuction(_bids[_id].amountToRaise);
    safeEngine.transferCollateral(collateralType, address(this), msg.sender, _bids[_id].amountToSell);
    delete _bids[_id];
    emit TerminateAuctionPrematurely(_id, msg.sender, _bids[_id].amountToSell);
  }

  // --- Getters ---

  /**
   * @dev Deprecated
   */
  function bidAmount(uint256) external pure returns (uint256) {
    return 0;
  }

  function remainingAmountToSell(uint256 _id) external view returns (uint256) {
    return _bids[_id].amountToSell;
  }

  function forgoneCollateralReceiver(uint256 _id) external view returns (address) {
    return _bids[_id].forgoneCollateralReceiver;
  }

  /**
   * @dev Deprecated
   */
  function raisedAmount(uint256) external pure returns (uint256) {
    return 0;
  }

  function amountToRaise(uint256 _id) external view returns (uint256) {
    return _bids[_id].amountToRaise;
  }
}
