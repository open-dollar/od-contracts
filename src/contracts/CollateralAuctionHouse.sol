// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';

/**
 * @title  CollateralAuctionHouse
 * @notice This contract enables the sell of a confiscated collateral in exchange for system coins to cover a SAFE's debt
 */
contract CollateralAuctionHouse is Authorizable, Modifiable, Disableable, ICollateralAuctionHouse {
  using Math for uint256;
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

  /// @inheritdoc ICollateralAuctionHouse
  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('COLLATERAL');

  // --- Registry ---

  /// @inheritdoc ICollateralAuctionHouse
  ISAFEEngine public safeEngine;

  /// @dev Internal storage variable to allow overrides in child implementation contract
  ILiquidationEngine internal _liquidationEngine;

  /// @dev Internal storage variable to allow overrides in child implementation contract
  IOracleRelayer internal _oracleRelayer;

  /// @inheritdoc ICollateralAuctionHouse
  function liquidationEngine() public view virtual returns (ILiquidationEngine __liquidationEngine) {
    return _liquidationEngine;
  }

  /// @inheritdoc ICollateralAuctionHouse
  function oracleRelayer() public view virtual returns (IOracleRelayer __oracleRelayer) {
    return _oracleRelayer;
  }

  // --- Data ---

  /// @inheritdoc ICollateralAuctionHouse
  bytes32 public collateralType;
  /// @inheritdoc ICollateralAuctionHouse
  uint256 public auctionsStarted;

  /// @inheritdoc ICollateralAuctionHouse
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 _auctionId => Auction) public _auctions;

  /// @inheritdoc ICollateralAuctionHouse
  function auctions(uint256 _auctionId) external view returns (Auction memory _auction) {
    return _auctions[_auctionId];
  }

  /// @inheritdoc ICollateralAuctionHouse
  // solhint-disable-next-line private-vars-leading-underscore
  CollateralAuctionHouseParams public _params;

  /// @inheritdoc ICollateralAuctionHouse
  function params() external view returns (CollateralAuctionHouseParams memory _cahParams) {
    return _params;
  }

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  __liquidationEngine Address of the LiquidationEngine contract
   * @param  __oracleRelayer Address of the OracleRelayer contract
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _cahParams Initial valid CollateralAuctionHouse parameters struct
   */
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

  // --- Internal Utils ---

  /**
   * @notice Get the amount of bought collateral from a specific auction using collateral and system coin prices, with a custom discount
   * @param  _collateralPrice The collateral price fetched from the Oracle
   * @param  _systemCoinPrice The system coin redemption price fetched from the OracleRelayer
   * @param  _amountToSell The amount of collateral being auctioned
   * @param  _adjustedBid The limited system coin bid
   * @param  _customDiscount The discount offered
   * @return _boughtCollateral Amount of collateral bought for given parameters
   * @return _readjustedBid Amount of system coins actually used to buy the collateral
   * @dev    The inputted bid is capped to the amount of system coins needed to buy all collateral
   */
  function _getBoughtCollateral(
    uint256 _collateralPrice,
    uint256 _systemCoinPrice,
    uint256 _amountToSell,
    uint256 _adjustedBid,
    uint256 _customDiscount
  ) internal pure returns (uint256 _boughtCollateral, uint256 _readjustedBid) {
    // calculate the collateral price in relation to the latest system coin price and apply the discount
    uint256 _discountedPrice = _collateralPrice.wmul(_customDiscount).rdiv(_systemCoinPrice);
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

  /**
   * @notice Get the collateral price from the oracle
   * @return _collateralPrice The collateral price if valid [wad]
   */
  function _getCollateralPrice() internal view returns (uint256 _collateralPrice) {
    IBaseOracle _oracle = oracleRelayer().cParams(collateralType).oracle;
    bool _hasValidValue;
    (_collateralPrice, _hasValidValue) = _oracle.getResultWithValidity();
    if (!_hasValidValue) return 0;

    return _collateralPrice;
  }

  /**
   * @notice Get the upcoming discount that will be used in a specific auction
   * @param  _id The ID of the auction to calculate the upcoming discount for
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
   * @param  _id The id of the auction to calculate the adjusted bid for
   * @param  _wad The initial bid submitted
   * @return _adjustedBid The adjusted bid
   * @dev    The inputted bid is capped to the amount of system coins the auction needs to raise
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

  // --- Auction Methods ---

  /// @inheritdoc ICollateralAuctionHouse
  function startAuction(
    address _forgoneCollateralReceiver,
    address _auctionIncomeRecipient,
    uint256 _amountToRaise,
    uint256 _amountToSell
  ) external isAuthorized whenEnabled returns (uint256 _id) {
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
      _auctioneer: msg.sender,
      _blockTimestamp: block.timestamp,
      _amountToSell: _amountToSell,
      _amountToRaise: _amountToRaise
    });
  }

  /// @inheritdoc ICollateralAuctionHouse
  function getAuctionDiscount(uint256 _id) external view returns (uint256 _auctionDiscount) {
    return _getAuctionDiscount(_id);
  }

  /// @inheritdoc ICollateralAuctionHouse
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

  /// @inheritdoc ICollateralAuctionHouse
  function buyCollateral(
    uint256 _id,
    uint256 _wad
  ) external whenEnabled returns (uint256 _boughtCollateral, uint256 _adjustedBid) {
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

    // Transfer the bid to the income recipient
    safeEngine.transferInternalCoins({
      _source: msg.sender,
      _destination: _auction.auctionIncomeRecipient,
      _rad: _adjustedBid * RAY
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

    // Transfer the collateral to the bidder
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
  }

  /// @inheritdoc ICollateralAuctionHouse
  function terminateAuctionPrematurely(uint256 _id) external isAuthorized {
    Auction memory _auction = _auctions[_id];
    delete _auctions[_id];

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
      _leftoverReceiver: msg.sender,
      _leftoverCollateral: _auction.amountToSell
    });
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
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

  /// @dev Sets the LiquidationEngine contract address, revoking the previous, and granting the new one authorization
  function _setLiquidationEngine(address _newLiquidationEngine) internal virtual {
    if (address(_liquidationEngine) != address(0)) _removeAuthorization(address(_liquidationEngine));
    _liquidationEngine = ILiquidationEngine(_newLiquidationEngine);
    _addAuthorization(_newLiquidationEngine);
  }

  /// @dev Sets the OracleRelayer contract address
  function _setOracleRelayer(address _newOracleRelayer) internal virtual {
    _oracleRelayer = IOracleRelayer(_newOracleRelayer);
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    // Registry
    address(liquidationEngine()).assertHasCode();
    address(oracleRelayer()).assertHasCode();
    // CAH Params
    _params.minDiscount.assertGtEq(_params.maxDiscount).assertLtEq(WAD);
    _params.maxDiscount.assertGt(0);
    _params.perSecondDiscountUpdateRate.assertLtEq(RAY);
  }
}
