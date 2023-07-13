// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  CollateralAuctionHouseFactory,
  ICollateralAuctionHouseFactory,
  EnumerableSet
} from '@contracts/factories/CollateralAuctionHouseFactory.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';

contract CollateralAuctionHouseFactoryForTest is CollateralAuctionHouseFactory {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(
    address _safeEngine,
    address _oracleRelayer,
    address _liquidationEngine,
    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams
  ) CollateralAuctionHouseFactory(_safeEngine, _oracleRelayer, _liquidationEngine, _cahParams) {}

  function addCollateralAuctionHouse(bytes32 _cType, address _collateralAuctionHouse) external {
    _collateralTypes.add(_cType);
    collateralAuctionHouses[_cType] = _collateralAuctionHouse;
  }

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }
}
