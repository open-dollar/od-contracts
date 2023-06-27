// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IIncreasingDiscountCollateralAuctionHouse} from '@interfaces/IIncreasingDiscountCollateralAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ICollateralAuctionHouseFactory is IAuthorizable, IDisableable, IModifiable {
  event DeployCollateralAuctionHouse(bytes32 indexed _cType, address indexed _collateralAuctionHouse);

  error CAHFactory_CAHExists();

  function params()
    external
    view
    returns (IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams);

  function cParams(bytes32 _cType)
    external
    view
    returns (IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams);

  // --- Registry ---
  function safeEngine() external view returns (address _safeEngine);
  function oracleRelayer() external view returns (address _oracleRelayer);
  function liquidationEngine() external view returns (address _liquidationEngine);

  // --- Data ---
  function collateralAuctionHouses(bytes32 _cType) external view returns (address _collateralAuctionHouse);
  function collateralTypesList() external view returns (bytes32[] memory _collateralTypes);
  function collateralAuctionHousesList() external view returns (address[] memory _collateralAuctionHouses);

  // --- Methods ---
  function deployCollateralAuctionHouse(
    bytes32 _cType,
    IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseParams calldata _cahCParams
  ) external returns (address _collateralAuctionHouse);
}
