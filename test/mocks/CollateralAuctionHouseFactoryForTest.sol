// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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
    address _liquidationEngine,
    address _oracleRelayer
  ) CollateralAuctionHouseFactory(_safeEngine, _liquidationEngine, _oracleRelayer) {}

  function addToCollateralList(bytes32 _cType) external {
    _collateralList.add(_cType);
  }

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }
}
