// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';

/*
   This thing lets you sell some collateral at an increasing discount in order to instantly recapitalize the system
*/
contract CollateralAuctionHouse is Authorizable, Modifiable, ICollateralAuctionHouse {
  using Math for uint256;
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('COLLATERAL');
  bytes32 public constant AUCTION_TYPE = bytes32('INCREASING_DISCOUNT');

  // --- Registry ---
  ISAFEEngine public safeEngine;
  IOracleRelayer internal _oracleRelayer;
  ILiquidationEngine internal _liquidationEngine;

  function liquidationEngine() public view virtual returns (ILiquidationEngine __liquidationEngine) {
    return _liquidationEngine;
  }

  function oracleRelayer() public view virtual returns (IOracleRelayer __oracleRelayer) {
    return _oracleRelayer;
  }

  // --- Data ---
  // Collateral type name
  bytes32 public collateralType;
  // Number of auctions started up until now
  uint256 public auctionsStarted;
  // The last read redemption price
  uint256 public lastReadRedemptionPrice;

  // Bid data for each separate auction
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 _auctionId => Auction) public _auctions;

  function auctions(uint256 _auctionId) external view returns (Auction memory _auction) {
    return _auctions[_auctionId];
  }

  CollateralAuctionHouseSystemCoinParams internal __params;

  function params() public view virtual returns (CollateralAuctionHouseSystemCoinParams memory _cahParams) {
    return __params;
  }

  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    virtual
    returns (uint256 _minSystemCoinDeviation, uint256 _lowerSystemCoinDeviation, uint256 _upperSystemCoinDeviation)
  {
    return (__params.minSystemCoinDeviation, __params.lowerSystemCoinDeviation, __params.upperSystemCoinDeviation);
  }

  // solhint-disable-next-line private-vars-leading-underscore
  CollateralAuctionHouseParams public _cParams;

  function cParams() external view returns (CollateralAuctionHouseParams memory _cahCParams) {
    return _cParams;
  }

  // --- Init ---
  constructor(
    address _safeEngine,
    address __oracleRelayer,
    address __liquidationEngine,
    bytes32 _cType,
    CollateralAuctionHouseSystemCoinParams memory _cahParams,
    CollateralAuctionHouseParams memory _cahCParams
  ) Authorizable(msg.sender) validParams validCParams(_cType) {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    _oracleRelayer = IOracleRelayer(__oracleRelayer);
    _setLiquidationEngine(__liquidationEngine);
    collateralType = _cType;

    __params = _cahParams;
    _cParams = _cahCParams;
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
    Auction memory _auction = _auctions[_id];
    _boughtCollateral = _boughtCollateral > _auction.amountToSell ? _auction.amountToSell : _boughtCollateral;
  }

  /**
   * @notice Update the discount used in a particular auction
   * @param _id The id of the auction to update the discount for
   * @return _updatedDiscount The newly computed currentDiscount for the targeted auction
   */
  function _updateCurrentDiscount(uint256 _id) internal virtual returns (uint256 _updatedDiscount) {
    // Work directly with storage
    Auction storage _auction = _auctions[_id];
    _auction.currentDiscount = _getNextCurrentDiscount(_id);
    _auction.latestDiscountUpdateTime = block.timestamp;
    _updatedDiscount = _auction.currentDiscount;
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
    // Fetch the collateral market address from the oracle relayer
    IDelayedOracle _delayedOracle = oracleRelayer().cParams(collateralType).oracle;
    IBaseOracle _marketOracle;

    try _delayedOracle.priceSource() returns (IBaseOracle __marketOracle) {
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
    IBaseOracle _systemCoinOracle = oracleRelayer().systemCoinOracle();
    if (address(_systemCoinOracle) == address(0)) return 0;

    // wrapped call toward the system coin oracle
    try _systemCoinOracle.getResultWithValidity() returns (uint256 _price, bool _valid) {
      if (_valid) {
        _priceFeed = uint256(_price) * 10 ** 9; // scale to RAY
      }
    } catch (bytes memory) {
      return 0;
    }
  }

  /**
   * @notice Get the smallest possible price that's at max lowerSystemCoinDeviation deviated from the redemption price and at least
   *         minSystemCoinDeviation deviated
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
    CollateralAuctionHouseSystemCoinParams memory _cahParams = params();
    uint256 _minFloorDeviatedPrice = _redemptionPrice.wmul(_cahParams.minSystemCoinDeviation);
    _floorPrice = _redemptionPrice.wmul(_cahParams.lowerSystemCoinDeviation);
    _floorPrice = _floorPrice <= _minFloorDeviatedPrice ? _floorPrice : _redemptionPrice;
  }

  /**
   * @notice Get the highest possible price that's at max upperSystemCoinDeviation deviated from the redemption price and at least
   *         minSystemCoinDeviation deviated
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
    CollateralAuctionHouseSystemCoinParams memory _cahParams = params();
    uint256 _minCeilingDeviatedPrice = _redemptionPrice.wmul(2 * WAD - _cahParams.minSystemCoinDeviation);
    _ceilingPrice = _redemptionPrice.wmul(2 * WAD - _cahParams.upperSystemCoinDeviation);
    _ceilingPrice = _ceilingPrice >= _minCeilingDeviatedPrice ? _ceilingPrice : _redemptionPrice;
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
    if (_systemCoinRedemptionPrice == 0) revert CAH_InvalidRedemptionPriceProvided();

    IDelayedOracle _delayedOracle = IDelayedOracle(address(oracleRelayer().cParams(collateralType).oracle));
    (uint256 _collateralFsmPriceFeedValue, bool _collateralFsmHasValidValue) = _delayedOracle.getResultWithValidity();
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
    uint256 _floorPrice = _collateralFsmPriceFeedValue.wmul(_cParams.lowerCollateralDeviation);
    uint256 _ceilingPrice = _collateralFsmPriceFeedValue.wmul(2 * WAD - _cParams.upperCollateralDeviation);

    _adjustedMarketPrice =
      (_collateralMarketPriceFeedValue == 0) ? _collateralFsmPriceFeedValue : _collateralMarketPriceFeedValue;

    if (_adjustedMarketPrice < _collateralFsmPriceFeedValue) {
      _adjustedMarketPrice = Math.max(_adjustedMarketPrice, _floorPrice);
    } else {
      _adjustedMarketPrice = Math.min(_adjustedMarketPrice, _ceilingPrice);
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
    Auction memory _auction = _auctions[_id];
    if (_auction.forgoneCollateralReceiver == address(0)) return RAY;
    _nextDiscount = _auction.currentDiscount;

    // If the current discount is not greater than max
    if (_auction.currentDiscount > _auction.maxDiscount) {
      // Calculate the new current discount
      _nextDiscount = _auction.perSecondDiscountUpdateRate.rpow(block.timestamp - _auction.latestDiscountUpdateTime)
        .rmul(_auction.currentDiscount);

      // If the new discount is greater than the max
      if (_nextDiscount <= _auction.maxDiscount) {
        // Top the next discount to max
        _nextDiscount = _auction.maxDiscount;
      }
    } else {
      _nextDiscount = _auction.maxDiscount;
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
    Auction memory _auction = _auctions[_id];
    if (_auction.amountToSell == 0 || _auction.amountToRaise == 0 || _wad == 0 || _wad < _cParams.minimumBid) {
      return (false, _wad);
    }

    uint256 _remainingToRaise = _auction.amountToRaise;

    // bound max amount offered in exchange for collateral
    _adjustedBid = _wad;
    if (_adjustedBid * RAY > _remainingToRaise) {
      _adjustedBid = (_remainingToRaise / RAY) + 1;
    }

    _remainingToRaise = _adjustedBid * RAY > _remainingToRaise ? 0 : _auction.amountToRaise - _adjustedBid * RAY;
    _valid = _remainingToRaise == 0 || _remainingToRaise >= RAY;
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
    uint256 _initialBid // TODO: deprecate and rm from LiqEngine
  ) external isAuthorized returns (uint256 _id) {
    return
      _startAuction(_forgoneCollateralReceiver, _auctionIncomeRecipient, _amountToRaise, _amountToSell, _initialBid);
  }

  // TODO: rm this internal method
  function _startAuction(
    address _forgoneCollateralReceiver,
    address _auctionIncomeRecipient,
    uint256 _amountToRaise,
    uint256 _amountToSell,
    uint256 _initialBid // TODO: deprecate and rm from LiqEngine
  ) internal virtual returns (uint256 _id) {
    if (_amountToSell == 0) revert CAH_NoCollateralForSale();
    if (_amountToRaise == 0) revert CAH_NothingToRaise();
    if (_amountToRaise < RAY) revert CAH_DustyAuction();
    _id = ++auctionsStarted;

    _auctions[_id] = Auction({
      currentDiscount: _cParams.minDiscount,
      maxDiscount: _cParams.maxDiscount,
      perSecondDiscountUpdateRate: _cParams.perSecondDiscountUpdateRate,
      latestDiscountUpdateTime: block.timestamp,
      amountToSell: _amountToSell,
      forgoneCollateralReceiver: _forgoneCollateralReceiver,
      auctionIncomeRecipient: _auctionIncomeRecipient,
      amountToRaise: _amountToRaise
    });

    safeEngine.transferCollateral({
      _cType: collateralType,
      _source: msg.sender,
      _destination: address(this),
      _wad: _amountToSell
    });

    emit StartAuction({
      _id: _id,
      _blockTimestamp: block.timestamp,
      _amountToSell: _amountToSell,
      _amountToRaise: _amountToRaise,
      _initialDiscount: _cParams.minDiscount,
      _maxDiscount: _cParams.maxDiscount,
      _perSecondDiscountUpdateRate: _cParams.perSecondDiscountUpdateRate
    });
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
      _auctions[_id].currentDiscount
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
    lastReadRedemptionPrice = oracleRelayer().redemptionPrice();

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
    Auction storage _auction = _auctions[_id];
    if (_auction.amountToSell == 0 || _auction.amountToRaise == 0) revert CAH_InexistentAuction();
    if (_wad == 0 || _wad < _cParams.minimumBid) revert CAH_InvalidBid();

    // bound max amount offered in exchange for collateral (in case someone offers more than it's necessary)
    uint256 _adjustedBid = _wad;
    if (_adjustedBid * RAY > _auction.amountToRaise) {
      _adjustedBid = _auction.amountToRaise / RAY + 1;
    }

    // Read the redemption price
    lastReadRedemptionPrice = oracleRelayer().redemptionPrice();

    // check that the collateral FSM doesn't return an invalid value
    (uint256 _collateralFsmPriceFeedValue, uint256 _systemCoinPriceFeedValue) =
      _getCollateralFSMAndFinalSystemCoinPrices(lastReadRedemptionPrice);
    if (_collateralFsmPriceFeedValue == 0) revert CAH_CollateralFSMInvalidValue();

    // get the amount of collateral bought
    uint256 _boughtCollateral = _getBoughtCollateral(
      _id,
      _collateralFsmPriceFeedValue,
      _getCollateralMarketPrice(),
      _systemCoinPriceFeedValue,
      _adjustedBid,
      _updateCurrentDiscount(_id)
    );
    // check that the calculated amount is greater than zero
    if (_boughtCollateral == 0) revert CAH_NullBoughtAmount();
    // update the amount of collateral to sell
    _auction.amountToSell = _auction.amountToSell - _boughtCollateral;

    // update remainingToRaise in case amountToSell is zero (everything has been sold)
    uint256 _remainingToRaise = _wad * RAY >= _auction.amountToRaise || _auction.amountToSell == 0
      ? _auction.amountToRaise
      : _auction.amountToRaise - (_wad * RAY);

    // update leftover amount to raise in the bid struct
    _auction.amountToRaise =
      _adjustedBid * RAY > _auction.amountToRaise ? 0 : _auction.amountToRaise - _adjustedBid * RAY;

    // check that the remaining amount to raise is either zero or higher than RAY
    if (_auction.amountToRaise != 0 && _auction.amountToRaise < RAY) revert CAH_InvalidLeftToRaise();

    // transfer the bid to the income recipient and the collateral to the bidder
    safeEngine.transferInternalCoins({
      _source: msg.sender,
      _destination: _auction.auctionIncomeRecipient,
      _rad: _adjustedBid * RAY
    });

    safeEngine.transferCollateral({
      _cType: collateralType,
      _source: address(this),
      _destination: msg.sender,
      _wad: _boughtCollateral
    });

    // Emit the buy event
    emit BuyCollateral({
      _id: _id,
      _bidder: msg.sender,
      _blockTimestamp: block.timestamp,
      _raisedAmount: _adjustedBid,
      _soldAmount: _boughtCollateral
    });

    // Remove coins from the liquidation buffer
    bool _soldAll = _auction.amountToRaise == 0 || _auction.amountToSell == 0;
    if (_soldAll) {
      liquidationEngine().removeCoinsFromAuction(_remainingToRaise);
    } else {
      liquidationEngine().removeCoinsFromAuction(_adjustedBid * RAY);
    }

    // If the auction raised the whole amount or all collateral was sold,
    // send remaining collateral to the forgone receiver
    if (_soldAll) {
      safeEngine.transferCollateral({
        _cType: collateralType,
        _source: address(this),
        _destination: _auction.forgoneCollateralReceiver,
        _wad: _auction.amountToSell
      });

      emit SettleAuction({
        _id: _id,
        _blockTimestamp: block.timestamp,
        _leftoverReceiver: _auction.forgoneCollateralReceiver,
        _leftoverCollateral: _auction.amountToSell
      });

      delete _auctions[_id];
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
  // TODO: why this method is not whenDisabled?
  function terminateAuctionPrematurely(uint256 _id) external isAuthorized {
    Auction memory _auction = _auctions[_id];

    if (_auction.amountToSell == 0 || _auction.amountToRaise == 0) revert CAH_InexistentAuction();
    liquidationEngine().removeCoinsFromAuction(_auction.amountToRaise);

    safeEngine.transferCollateral({
      _cType: collateralType,
      _source: address(this),
      _destination: msg.sender,
      _wad: _auction.amountToSell
    });

    emit TerminateAuctionPrematurely({
      _id: _id,
      _blockTimestamp: block.timestamp,
      _leftoverReceiver: _auction.forgoneCollateralReceiver,
      _leftoverCollateral: _auction.amountToSell
    });

    delete _auctions[_id];
  }

  // --- Getters ---
  /**
   * @dev Deprecated
   */
  function bidAmount(uint256) external pure returns (uint256 _bidAmount) {
    return 0;
  }

  function remainingAmountToSell(uint256 _id) external view returns (uint256 _remainingAmountToSell) {
    return _auctions[_id].amountToSell;
  }

  function forgoneCollateralReceiver(uint256 _id) external view returns (address _forgoneCollateralReceiver) {
    return _auctions[_id].forgoneCollateralReceiver;
  }

  /**
   * @dev Deprecated
   */
  function raisedAmount(uint256) external pure returns (uint256 _raisedAmount) {
    return 0;
  }

  function amountToRaise(uint256 _id) external view returns (uint256 _amountToRaise) {
    return _auctions[_id].amountToRaise;
  }

  // --- Administration ---
  function _modifyParameters(bytes32 _param, bytes memory _data) internal virtual override {
    uint256 _uint256 = _data.toUint256();
    address _address = _data.toAddress();

    // Registry
    if (_param == 'oracleRelayer') _oracleRelayer = IOracleRelayer(_address);
    else if (_param == 'liquidationEngine') _setLiquidationEngine(_address);
    // SystemCoin Params
    else if (_param == 'lowerSystemCoinDeviation') __params.lowerSystemCoinDeviation = _uint256;
    else if (_param == 'upperSystemCoinDeviation') __params.upperSystemCoinDeviation = _uint256;
    else if (_param == 'minSystemCoinDeviation') __params.minSystemCoinDeviation = _uint256;
    else revert UnrecognizedParam();
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal virtual override {
    uint256 _uint256 = _data.toUint256();

    // Checks that the inputted collateral type is the contract's one
    if (_cType != collateralType) revert UnrecognizedCType();
    // CAH Params
    if (_param == 'minDiscount') _cParams.minDiscount = _uint256;
    else if (_param == 'maxDiscount') _cParams.maxDiscount = _uint256;
    else if (_param == 'perSecondDiscountUpdateRate') _cParams.perSecondDiscountUpdateRate = _uint256;
    else if (_param == 'lowerCollateralDeviation') _cParams.lowerCollateralDeviation = _uint256;
    else if (_param == 'upperCollateralDeviation') _cParams.upperCollateralDeviation = _uint256;
    else if (_param == 'minimumBid') _cParams.minimumBid = _uint256;
    else revert UnrecognizedParam();
  }

  function _setLiquidationEngine(address _newLiquidationEngine) internal virtual {
    if (address(_liquidationEngine) != address(0)) _removeAuthorization(address(_liquidationEngine));
    _liquidationEngine = ILiquidationEngine(_newLiquidationEngine);
    _addAuthorization(_newLiquidationEngine);
  }

  function _validateParameters() internal view override {
    // SystemCoin Parameters
    CollateralAuctionHouseSystemCoinParams memory _cahParams = params();
    _cahParams.lowerSystemCoinDeviation.assertLtEq(WAD);
    _cahParams.upperSystemCoinDeviation.assertLtEq(WAD);

    // Registry
    address(oracleRelayer()).assertNonNull();
    address(liquidationEngine()).assertNonNull();
  }

  function _validateCParameters(bytes32) internal view override {
    // Collateral Parameters
    _cParams.minDiscount.assertGtEq(_cParams.maxDiscount).assertLtEq(WAD);
    _cParams.maxDiscount.assertGt(0).assertLtEq(_cParams.minDiscount);
    _cParams.perSecondDiscountUpdateRate.assertLtEq(RAY);
    _cParams.lowerCollateralDeviation.assertLtEq(WAD);
    _cParams.upperCollateralDeviation.assertLtEq(WAD);
  }
}
