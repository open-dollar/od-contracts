// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IncreasingDiscountCollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {InternalCallsExtension} from '@test/utils/InternalCallsWatcher.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

// solhint-disable
contract CollateralAuctionHouseForTest {
  uint256 auctionId = 123_456;

  function startAuction(
    address _forgoneCollateralReceiver,
    address _initialBidder,
    uint256 _amountToRaise,
    uint256 _collateralToSell,
    uint256 _initialBid
  ) external returns (uint256 _id) {
    return auctionId;
  }
}

contract IncreasingDiscountCollateralAuctionHouseForTest is
  IncreasingDiscountCollateralAuctionHouse,
  InternalCallsExtension
{
  MockCollateralAuctionHouse mockCollateralAuctionHouse;

  constructor(
    address _safeEngine,
    address _liquidationEngine,
    bytes32 _collateralType,
    MockCollateralAuctionHouse _mockCollateralAuctionHouse
  ) IncreasingDiscountCollateralAuctionHouse(_safeEngine, _liquidationEngine, _collateralType) {
    mockCollateralAuctionHouse = _mockCollateralAuctionHouse;
  }

  bool callSupper_getDiscountedCollateralPrice = true;

  function setCallSupper_getDiscountedCollateralPrice(bool _callSuper) external {
    callSupper_getDiscountedCollateralPrice = _callSuper;
  }

  function _getDiscountedCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _customDiscount
  ) internal view virtual override returns (uint256 _discountedCollateralPrice) {
    watcher.calledInternal(
      abi.encodeWithSignature(
        '_getDiscountedCollateralPrice(uint256,uint256,uint256,uint256)',
        _collateralFsmPriceFeedValue,
        _collateralMarketPriceFeedValue,
        _systemCoinPriceFeedValue,
        _customDiscount
      )
    );
    if (callSuper || callSupper_getDiscountedCollateralPrice) {
      return super._getDiscountedCollateralPrice(
        _collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue, _systemCoinPriceFeedValue, _customDiscount
      );
    } else {
      return mockCollateralAuctionHouse.mock_getDiscountedCollateralPrice(
        _collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue, _systemCoinPriceFeedValue, _customDiscount
      );
    }
  }

  function _getNextCurrentDiscount(uint256 _id) internal view virtual override returns (uint256 _nextDiscount) {
    watcher.calledInternal(abi.encodeWithSignature('_getNextCurrentDiscount(uint256)', _id));
    if (callSuper) {
      return super._getNextCurrentDiscount(_id);
    } else {
      return mockCollateralAuctionHouse.mock_getNextCurrentDiscount(_id);
    }
  }

  function _getSystemCoinMarketPrice() internal view virtual override returns (uint256 _priceFeed) {
    watcher.calledInternal(abi.encodeWithSignature('_getSystemCoinMarketPrice()'));
    if (callSuper) {
      return super._getSystemCoinMarketPrice();
    } else {
      return mockCollateralAuctionHouse.mock_getSystemCoinMarketPrice();
    }
  }

  bool callSupper_getFinalSystemCoinPrice = true;

  function setCallSupper_getFinalSystemCoinPrice(bool _callSuper) external {
    callSupper_getFinalSystemCoinPrice = _callSuper;
  }

  function _getFinalSystemCoinPrice(
    uint256 _systemCoinRedemptionPrice,
    uint256 _systemCoinMarketPrice
  ) internal view virtual override returns (uint256 _finalSystemCoinPrice) {
    watcher.calledInternal(
      abi.encodeWithSignature(
        '_getFinalSystemCoinPrice(uint256,uint256)', _systemCoinRedemptionPrice, _systemCoinMarketPrice
      )
    );
    if (callSuper || callSupper_getFinalSystemCoinPrice) {
      return super._getFinalSystemCoinPrice(_systemCoinRedemptionPrice, _systemCoinMarketPrice);
    } else {
      return mockCollateralAuctionHouse.mock_getFinalSystemCoinPrice(_systemCoinRedemptionPrice, _systemCoinMarketPrice);
    }
  }

  function _getFinalBaseCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue
  ) internal view virtual override returns (uint256 _adjustedMarketPrice) {
    watcher.calledInternal(
      abi.encodeWithSignature(
        '_getFinalBaseCollateralPrice(uint256,uint256)', _collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue
      )
    );
    if (callSuper) {
      return super._getFinalBaseCollateralPrice(_collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue);
    } else {
      return mockCollateralAuctionHouse.mock_getFinalBaseCollateralPrice(
        _collateralFsmPriceFeedValue, _collateralMarketPriceFeedValue
      );
    }
  }

  function _getSystemCoinFloorDeviatedPrice(uint256 _redemptionPrice)
    internal
    view
    virtual
    override
    returns (uint256 _floorPrice)
  {
    watcher.calledInternal(abi.encodeWithSignature('_getSystemCoinFloorDeviatedPrice(uint256)', _redemptionPrice));
    if (callSuper) {
      return super._getSystemCoinFloorDeviatedPrice(_redemptionPrice);
    } else {
      return mockCollateralAuctionHouse.mock_getSystemCoinFloorDeviatedPrice(_redemptionPrice);
    }
  }

  function _getSystemCoinCeilingDeviatedPrice(uint256 _redemptionPrice)
    internal
    view
    virtual
    override
    returns (uint256 _ceilingPrice)
  {
    watcher.calledInternal(abi.encodeWithSignature('_getSystemCoinCeilingDeviatedPrice(uint256)', _redemptionPrice));
    if (callSuper) {
      return super._getSystemCoinCeilingDeviatedPrice(_redemptionPrice);
    } else {
      return mockCollateralAuctionHouse.mock_getSystemCoinCeilingDeviatedPrice(_redemptionPrice);
    }
  }

  function _getAdjustedBid(
    uint256 _id,
    uint256 _wad
  ) internal view virtual override returns (bool _valid, uint256 _adjustedBid) {
    watcher.calledInternal(abi.encodeWithSignature('_getAdjustedBid(uint256,uint256)', _id, _wad));
    if (callSuper) {
      return super._getAdjustedBid(_id, _wad);
    } else {
      return mockCollateralAuctionHouse.mock_getAdjustedBid(_id, _wad);
    }
  }

  function _getBoughtCollateral(
    uint256 _id,
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _adjustedBid,
    uint256 _customDiscount
  ) internal view virtual override returns (uint256 _boughtCollateral) {
    watcher.calledInternal(
      abi.encodeWithSignature(
        '_getBoughtCollateral(uint256,uint256,uint256,uint256,uint256,uint256)',
        _id,
        _collateralFsmPriceFeedValue,
        _collateralMarketPriceFeedValue,
        _systemCoinPriceFeedValue,
        _adjustedBid,
        _customDiscount
      )
    );
    if (callSuper) {
      return super._getBoughtCollateral(
        _id,
        _collateralFsmPriceFeedValue,
        _collateralMarketPriceFeedValue,
        _systemCoinPriceFeedValue,
        _adjustedBid,
        _customDiscount
      );
    } else {
      return mockCollateralAuctionHouse.mock_getBoughtCollateral(
        _id,
        _collateralFsmPriceFeedValue,
        _collateralMarketPriceFeedValue,
        _systemCoinPriceFeedValue,
        _adjustedBid,
        _customDiscount
      );
    }
  }

  function _getCollateralMarketPrice() internal view virtual override returns (uint256 _priceFeed) {
    watcher.calledInternal(abi.encodeWithSignature('_getCollateralMarketPrice()'));
    if (callSuper) {
      return super._getCollateralMarketPrice();
    } else {
      return mockCollateralAuctionHouse.mock_getCollateralMarketPrice();
    }
  }

  function _updateCurrentDiscount(uint256 _id) internal virtual override returns (uint256 _updatedDiscount) {
    watcher.calledInternal(abi.encodeWithSignature('_updateCurrentDiscount(uint256)', _id));
    if (callSuper) {
      return super._updateCurrentDiscount(_id);
    } else {
      return mockCollateralAuctionHouse.mock_updateCurrentDiscount(_id);
    }
  }

  bool callSupper_getCollateralFSMAndFinalSystemCoinPrices = true;

  function setCallSupper_getCollateralFSMAndFinalSystemCoinPrices(bool _callSuper) external {
    callSupper_getCollateralFSMAndFinalSystemCoinPrices = _callSuper;
  }

  function _getCollateralFSMAndFinalSystemCoinPrices(uint256 _systemCoinRedemptionPrice)
    internal
    view
    virtual
    override
    returns (uint256 _cFsmPriceFeedValue, uint256 _sCoinAdjustedPrice)
  {
    watcher.calledInternal(
      abi.encodeWithSignature('_getCollateralFSMAndFinalSystemCoinPrices(uint256)', _systemCoinRedemptionPrice)
    );
    if (callSuper || callSupper_getCollateralFSMAndFinalSystemCoinPrices) {
      return super._getCollateralFSMAndFinalSystemCoinPrices(_systemCoinRedemptionPrice);
    } else {
      return mockCollateralAuctionHouse.mock_getCollateralFSMAndFinalSystemCoinPrices(_systemCoinRedemptionPrice);
    }
  }

  function mock_pushBid(Auction memory _auction) external {
    uint256 _id = ++auctionsStarted;
    _auctions[_id] = _auction;
  }

  function call_getBoughtCollateral(
    uint256 _id,
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _adjustedBid,
    uint256 _customDiscount
  ) external view returns (uint256 _boughtCollateral) {
    return super._getBoughtCollateral(
      _id,
      _collateralFsmPriceFeedValue,
      _collateralMarketPriceFeedValue,
      _systemCoinPriceFeedValue,
      _adjustedBid,
      _customDiscount
    );
  }

  function call_updateCurrentDiscount(uint256 _id) external returns (uint256) {
    return super._updateCurrentDiscount(_id);
  }

  function setCollateralFSM(IDelayedOracle _collateralFSM) external {
    collateralFSM = _collateralFSM;
  }

  function setSystemCoinOracle(IBaseOracle _systemCoinOracle) external {
    systemCoinOracle = _systemCoinOracle;
  }

  function setOracleRelayer(IOracleRelayer _oracleRelayer) external {
    oracleRelayer = _oracleRelayer;
  }
}

contract MockCollateralAuctionHouse {
  function mock_getDiscountedCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _customDiscount
  ) external view returns (uint256 _discountedCollateralPrice) {}

  function mock_getNextCurrentDiscount(uint256 _id) external view returns (uint256 _nextDiscount) {}

  function mock_getSystemCoinMarketPrice() external view returns (uint256 _priceFeed) {}

  function mock_getFinalSystemCoinPrice(
    uint256 _systemCoinRedemptionPrice,
    uint256 _systemCoinMarketPrice
  ) external view returns (uint256 _finalSystemCoinPrice) {}

  function mock_getFinalBaseCollateralPrice(
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue
  ) external view returns (uint256 _adjustedMarketPrice) {}

  function mock_getSystemCoinFloorDeviatedPrice(uint256 _redemptionPrice) external view returns (uint256 _floorPrice) {}

  function mock_getSystemCoinCeilingDeviatedPrice(uint256 _redemptionPrice)
    external
    view
    returns (uint256 _ceilingPrice)
  {}

  function mock_getAdjustedBid(uint256 _id, uint256 _wad) external view returns (bool _valid, uint256 _adjustedBid) {}

  function mock_getCollateralFSMAndFinalSystemCoinPrices(uint256 _systemCoinRedemptionPrice)
    external
    view
    returns (uint256 _cFsmPriceFeedValue, uint256 _sCoinAdjustedPrice)
  {}

  function mock_getBoughtCollateral(
    uint256 _id,
    uint256 _collateralFsmPriceFeedValue,
    uint256 _collateralMarketPriceFeedValue,
    uint256 _systemCoinPriceFeedValue,
    uint256 _adjustedBid,
    uint256 _customDiscount
  ) external view returns (uint256 _boughtCollateral) {}

  function mock_getCollateralMarketPrice() external view returns (uint256 _priceFeed) {}

  function mock_updateCurrentDiscount(uint256 _id) external returns (uint256 _updatedDiscount) {}
}
