// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ICollateralAuctionHouseFactory is IAuthorizable, IDisableable, IModifiable {
  event DeployCollateralAuctionHouse(bytes32 indexed _cType, address indexed _collateralAuctionHouse);

  error CAHFactory_CAHExists();

  function cParams(bytes32 _cType)
    external
    view
    returns (ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (uint256 _minimumBid, uint256 _minDiscount, uint256 _maxDiscount, uint256 _perSecondDiscountUpdateRate);

  // --- Registry ---
  function safeEngine() external view returns (address _safeEngine);
  function liquidationEngine() external view returns (address _liquidationEngine);
  function oracleRelayer() external view returns (address _oracleRelayer);

  // --- Data ---
  function collateralAuctionHouses(bytes32 _cType) external view returns (address _collateralAuctionHouse);
  function collateralList() external view returns (bytes32[] memory __collateralList);
  function collateralAuctionHousesList() external view returns (address[] memory _collateralAuctionHouses);

  // --- Methods ---
  function deployCollateralAuctionHouse(
    bytes32 _cType,
    ICollateralAuctionHouse.CollateralAuctionHouseParams calldata _cahParams
  ) external returns (ICollateralAuctionHouse _collateralAuctionHouse);
}
