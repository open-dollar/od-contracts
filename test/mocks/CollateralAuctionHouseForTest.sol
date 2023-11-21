// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';

// solhint-disable
contract DummyCollateralAuctionHouse {
  uint256 auctionId = 123_456;

  function startAuction(
    address _forgoneCollateralReceiver,
    address _initialBidder,
    uint256 _amountToRaise,
    uint256 _collateralToSell
  ) external view returns (uint256 _id) {
    return auctionId;
  }
}

contract CollateralAuctionHouseForTest is CollateralAuctionHouse {
  constructor(
    address _safeEngine,
    address _liquidationEngine,
    address _oracleRelayer,
    bytes32 _cType,
    CollateralAuctionHouseParams memory _cahParams
  ) CollateralAuctionHouse(_safeEngine, _liquidationEngine, _oracleRelayer, _cType, _cahParams) {}

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }

  function addAuction(
    uint256 _id,
    uint256 _amountToSell,
    uint256 _amountToRaise,
    uint256 _initialTimestamp,
    address _forgoneCollateralReceiver,
    address _auctionIncomeRecipient
  ) external {
    _auctions[_id].amountToSell = _amountToSell;
    _auctions[_id].amountToRaise = _amountToRaise;
    _auctions[_id].initialTimestamp = _initialTimestamp;
    _auctions[_id].forgoneCollateralReceiver = _forgoneCollateralReceiver;
    _auctions[_id].auctionIncomeRecipient = _auctionIncomeRecipient;
  }

  function getAdjustedBid(uint256 _id, uint256 _wad) external view returns (uint256 _adjustedBid) {
    return _getAdjustedBid(_id, _wad);
  }

  function getCollateralPrice() external view returns (uint256 _collateralPrice) {
    return _getCollateralPrice();
  }

  function getBoughtCollateral(
    uint256 _collateralPrice,
    uint256 _systemCoinPrice,
    uint256 _amountToSell,
    uint256 _adjustedBid,
    uint256 _customDiscount
  ) external pure returns (uint256 _boughtCollateral, uint256 _readjustedBid) {
    return _getBoughtCollateral(_collateralPrice, _systemCoinPrice, _amountToSell, _adjustedBid, _customDiscount);
  }
}
