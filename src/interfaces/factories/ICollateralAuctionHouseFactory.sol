// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IIncreasingDiscountCollateralAuctionHouse} from '@interfaces/IIncreasingDiscountCollateralAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ICollateralAuctionHouseFactory is IAuthorizable, IDisableable, IModifiable {
  event DeployCollateralAuctionHouse(
    bytes32 indexed _cType, address indexed _collateral, address indexed _collateralAuctionHouse
  );
  event DisableCollateralAuctionHouse(address indexed _collateralAuctionHouse);

  error CollateralAuctionHouseFactory_NotCollateralAuctionHouse();

  function params()
    external
    view
    returns (IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams);

  function oracleRelayer() external view returns (address _oracleRelayer);
  function liquidationEngine() external view returns (address _liquidationEngine);
}
