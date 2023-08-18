// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

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
  ILiquidationEngine internal _liquidationEngine;
  IOracleRelayer internal _oracleRelayer;

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

  // Bid data for each separate auction
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 _auctionId => Auction) public _auctions;

  function auctions(uint256 _auctionId) external view returns (Auction memory _auction) {
    return _auctions[_auctionId];
  }

  // solhint-disable-next-line private-vars-leading-underscore
  CollateralAuctionHouseParams public _params;

  function params() external view returns (CollateralAuctionHouseParams memory _cahParams) {
    return _params;
  }

  // --- Init ---
  constructor(
    address _safeEngine,
    address __liquidationEngine,
    address __oracleRelayer,
    bytes32 _cType,
    CollateralAuctionHouseParams memory _cahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    _setLiquidationEngine(__liquidationEngine);
    _setOracleRelayer(__oracleRelayer);
    collateralType = _cType;

    _params = _cahParams;
  }

  // --- Private Auction Utils ---
  /**
   * @notice Get the amount of bought collateral from a specific auction using custom collateral price feeds, a system
   *         coin price feed and a custom discount
   * @param  _collateralPrice The collateral price fetched from the Oracle
   * @param  _systemCoinPrice The system coin redemption price fetched from the OracleRelayer
   * @param  _amountToSell The amount of collateral being auctioned
   * @param  _adjustedBid The limited system coin bid
   * @param  _customDiscount The discount offered
   * @return _boughtCollateral Amount of collateral bought for given parameters
   */
  function _getBoughtCollateral(
    uint256 _collateralPrice,
    uint256 _systemCoinPrice,
    uint256 _amountToSell,
    uint256 _adjustedBid,
    uint256 _customDiscount
  ) internal pure returns (uint256 _boughtCollateral, uint256 _readjustedBid) {
    // calculate the collateral price in relation to the latest system coin price and apply the discount
    uint256 _discountedPrice = _collateralPrice.rdiv(_systemCoinPrice).wmul(_customDiscount);
    // calculate the amount of collateral bought
    _boughtCollateral = _adjustedBid.wdiv(_discountedPrice);

    if (_boughtCollateral <= _amountToSell) {
      return (_boughtCollateral, _adjustedBid);
    } else {
      // if calculated collateral amount exceeds the amount for sale, adjust it to the remaining amount
      _readjustedBid = _adjustedBid * _amountToSell / _boughtCollateral;
      return (_amountToSell, _readjustedBid);
    }
  }

  function _getCollateralPrice() internal view returns (uint256 _collateralPrice) {
    IDelayedOracle _delayedOracle = oracleRelayer().cParams(collateralType).oracle;
    bool _hasValidValue;
    (_collateralPrice, _hasValidValue) = _delayedOracle.getResultWithValidity();
    if (!_hasValidValue) return 0;

    return _collateralPrice;
  }

  /**
   * @notice Get the upcoming discount that will be used in a specific auction
   * @param _id The ID of the auction to calculate the upcoming discount for
   * @return _auctionDiscount The upcoming discount that will be used in the targeted auction
   */
  function _getAuctionDiscount(uint256 _id) internal view returns (uint256 _auctionDiscount) {
    uint256 _auctionTimestamp = _auctions[_id].initialTimestamp;
    if (_auctionTimestamp == 0) return WAD; // auction is finished, return no discount

    uint256 _timeSinceCreation = block.timestamp - _auctionTimestamp;
    _auctionDiscount = _params.perSecondDiscountUpdateRate.rpow(_timeSinceCreation).rmul(_params.minDiscount);

    if (_auctionDiscount < _params.maxDiscount) return _params.maxDiscount;
  }

  /**
   * @notice Get the actual bid that will be used in an auction (taking into account the bidder input)
   * @param _id The id of the auction to calculate the adjusted bid for
   * @param _wad The initial bid submitted
   * @return _adjustedBid The adjusted bid
   */
  function _getAdjustedBid(uint256 _id, uint256 _wad) internal view returns (uint256 _adjustedBid) {
    Auction memory _auction = _auctions[_id];
    if (_auction.amountToRaise == 0 || _auction.amountToSell == 0) return 0;

    // bound max amount offered in exchange for collateral
    _adjustedBid = _wad;
    if (_adjustedBid * RAY > _auction.amountToRaise) {
      _adjustedBid = (_auction.amountToRaise / RAY) + 1;
    }
  }

  // --- Core Auction Logic ---
  /**
   * @notice Start a new collateral auction
   * @param _forgoneCollateralReceiver Who receives leftover collateral that is not auctioned
   * @param _auctionIncomeRecipient Who receives the amount raised in the auction
   * @param _amountToRaise Total amount of coins to raise (rad)
   * @param _amountToSell Total amount of collateral available to sell (wad)
   */
  function startAuction(
    address _forgoneCollateralReceiver,
    address _auctionIncomeRecipient,
    uint256 _amountToRaise,
    uint256 _amountToSell
  ) external isAuthorized returns (uint256 _id) {
    if (_amountToSell == 0) revert CAH_NoCollateralForSale();
    if (_amountToRaise == 0) revert CAH_NothingToRaise();
    if (_amountToRaise < RAY) revert CAH_DustyAuction();
    _id = ++auctionsStarted;

    _auctions[_id] = Auction({
      amountToSell: _amountToSell,
      amountToRaise: _amountToRaise,
      initialTimestamp: block.timestamp,
      forgoneCollateralReceiver: _forgoneCollateralReceiver,
      auctionIncomeRecipient: _auctionIncomeRecipient
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
      _amountToRaise: _amountToRaise
    });
  }

  function getAuctionDiscount(uint256 _id) external view returns (uint256 _auctionDiscount) {
    return _getAuctionDiscount(_id);
  }

  /**
   * @notice Calculate how much collateral someone would buy from an auction using the last read redemption price and the old current
   *         discount associated with the auction
   * @param _id ID of the auction to buy collateral from
   * @param _wad New bid submitted
   */
  function getCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external view returns (uint256 _boughtCollateral, uint256 _adjustedBid) {
    _adjustedBid = _getAdjustedBid(_id, _wad);
    if (_adjustedBid == 0) return (0, 0);

    // Read (but not update) redemption price
    uint256 _calcRedemptionPrice = oracleRelayer().calcRedemptionPrice();
    if (_calcRedemptionPrice == 0) revert CAH_InvalidRedemptionPriceProvided();

    // check that the oracle doesn't return an invalid value
    uint256 _collateralPrice = _getCollateralPrice();
    if (_collateralPrice == 0) return (0, _adjustedBid);

    (_boughtCollateral, _adjustedBid) = _getBoughtCollateral(
      _collateralPrice, _calcRedemptionPrice, _auctions[_id].amountToSell, _adjustedBid, _getAuctionDiscount(_id)
    );
  }

  /**
   * @notice Buy collateral from an auction at an increasing discount
   * @param _id ID of the auction to buy collateral from
   * @param _wad New bid submitted (as a WAD which has 18 decimals)
   * @return _boughtCollateral Amount of collateral bought
   * @return _adjustedBid The amount of coins used to buy the collateral (in WAD)
   */
  function buyCollateral(uint256 _id, uint256 _wad) external returns (uint256 _boughtCollateral, uint256 _adjustedBid) {
    Auction storage _auction = _auctions[_id];
    if (_wad == 0 || _wad < _params.minimumBid) revert CAH_InvalidBid();

    // Bound max amount offered in exchange for collateral (in case someone offers more than it's necessary)
    _adjustedBid = _getAdjustedBid(_id, _wad);
    if (_adjustedBid == 0) revert CAH_InexistentAuction();

    // Read (and update) the redemption price
    uint256 _redemptionPrice = oracleRelayer().redemptionPrice();
    if (_redemptionPrice == 0) revert CAH_InvalidRedemptionPriceProvided();

    // Read and check the collateral price
    uint256 _collateralPrice = _getCollateralPrice();
    if (_collateralPrice == 0) revert CAH_CollateralOracleInvalidValue();

    // Get and check the amount of collateral bought
    (_boughtCollateral, _adjustedBid) = _getBoughtCollateral(
      _collateralPrice, _redemptionPrice, _auction.amountToSell, _adjustedBid, _getAuctionDiscount(_id)
    );
    if (_boughtCollateral == 0) revert CAH_NullBoughtAmount();

    // Transfer the bid to the income recipient and the collateral to the bidder
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

    if (_adjustedBid * RAY < _auction.amountToRaise && _auction.amountToSell > _boughtCollateral) {
      // --- Partial bid ---
      // If the bid doesn't raise the whole amount or purchase all collateral to sell:

      // Update the amount of collateral to sell
      _auction.amountToSell -= _boughtCollateral;

      // Update leftover amount to raise in the bid struct
      _auction.amountToRaise -= _adjustedBid * RAY;

      // Check that the remaining amount to raise is higher than minimum bid
      if (_auction.amountToRaise < _params.minimumBid * RAY) revert CAH_InvalidLeftToRaise();

      // Remove raised amount from the liquidation engine queue
      liquidationEngine().removeCoinsFromAuction(_adjustedBid * RAY);
    } else {
      // --- Full bid ---
      // If the bid raises the whole amount left or purchases all collateral left:

      // Calculate (if any) the remaining collateral to send to the forgone receiver
      uint256 _remainingCollateral = _auction.amountToSell - _boughtCollateral;

      if (_remainingCollateral > 0) {
        // Send remaining collateral to the forgone receiver
        safeEngine.transferCollateral({
          _cType: collateralType,
          _source: address(this),
          _destination: _auction.forgoneCollateralReceiver,
          _wad: _remainingCollateral
        });
      }

      // Remove remaining to raise from the liquidation engine queue
      liquidationEngine().removeCoinsFromAuction(_auction.amountToRaise);

      emit SettleAuction({
        _id: _id,
        _blockTimestamp: block.timestamp,
        _leftoverReceiver: _auction.forgoneCollateralReceiver,
        _leftoverCollateral: _remainingCollateral
      });

      // Delete the auction
      delete _auctions[_id];
    }

    // Emit the buy event
    emit BuyCollateral({
      _id: _id,
      _bidder: msg.sender,
      _blockTimestamp: block.timestamp,
      _raisedAmount: _adjustedBid,
      _soldAmount: _boughtCollateral
    });
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
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    // Registry
    // NOTE: in Child implementation registry is read from the factory, modifying it has no effect
    if (_param == 'liquidationEngine') _setLiquidationEngine(_address);
    else if (_param == 'oracleRelayer') _setOracleRelayer(_address);
    // CAH Params
    else if (_param == 'minimumBid') _params.minimumBid = _uint256;
    else if (_param == 'minDiscount') _params.minDiscount = _uint256;
    else if (_param == 'maxDiscount') _params.maxDiscount = _uint256;
    else if (_param == 'perSecondDiscountUpdateRate') _params.perSecondDiscountUpdateRate = _uint256;
    else revert UnrecognizedParam();
  }

  function _setLiquidationEngine(address _newLiquidationEngine) internal virtual {
    if (address(_liquidationEngine) != address(0)) _removeAuthorization(address(_liquidationEngine));
    _liquidationEngine = ILiquidationEngine(_newLiquidationEngine);
    _addAuthorization(_newLiquidationEngine);
  }

  function _setOracleRelayer(address _newOracleRelayer) internal virtual {
    _oracleRelayer = IOracleRelayer(_newOracleRelayer);
  }

  function _validateParameters() internal view override {
    // Registry
    address(liquidationEngine()).assertNonNull();
    address(oracleRelayer()).assertNonNull();
    // CAH Params
    _params.minDiscount.assertGtEq(_params.maxDiscount).assertLtEq(WAD);
    _params.maxDiscount.assertGt(0);
    _params.perSecondDiscountUpdateRate.assertLtEq(RAY);
  }
}
