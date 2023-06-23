// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouseChild} from '@interfaces/factories/ICollateralAuctionHouseChild.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {
  IncreasingDiscountCollateralAuctionHouse,
  IIncreasingDiscountCollateralAuctionHouse
} from '@contracts/CollateralAuctionHouse.sol';

import {AuthorizableChild, Authorizable} from '@contracts/factories/AuthorizableChild.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

/**
 * @title  CollateralAuctionHouseChild
 * @notice This contract inherits all the functionality of `CollateralAuctionHouse.sol` to be factory deployed
 */
contract CollateralAuctionHouseChild is
  AuthorizableChild,
  IncreasingDiscountCollateralAuctionHouse,
  ICollateralAuctionHouseChild
{
  using EnumerableSet for EnumerableSet.AddressSet;
  using Math for uint256;

  // --- Init ---
  constructor(
    address _safeEngine,
    address _oracleRelayer,
    address _liquidationEngine,
    bytes32 _collateralType,
    CollateralAuctionHouseSystemCoinParams memory _cahParams,
    CollateralAuctionHouseParams memory _cahCParams
  )
    IncreasingDiscountCollateralAuctionHouse(
      _safeEngine,
      _oracleRelayer, // empty
      _liquidationEngine, // empty
      _collateralType,
      _cahParams, // empty
      _cahCParams
    )
  {}

  function params()
    public
    view
    override(IncreasingDiscountCollateralAuctionHouse, IIncreasingDiscountCollateralAuctionHouse)
    returns (CollateralAuctionHouseSystemCoinParams memory _cahParams)
  {
    return ICollateralAuctionHouseFactory(factory).params();
  }

  function liquidationEngine()
    public
    view
    override(IncreasingDiscountCollateralAuctionHouse, IIncreasingDiscountCollateralAuctionHouse)
    returns (ILiquidationEngine _liquidationEngine)
  {
    return ILiquidationEngine(ICollateralAuctionHouseFactory(factory).liquidationEngine());
  }

  function oracleRelayer()
    public
    view
    override(IncreasingDiscountCollateralAuctionHouse, IIncreasingDiscountCollateralAuctionHouse)
    returns (IOracleRelayer _oracleRelayer)
  {
    return IOracleRelayer(ICollateralAuctionHouseFactory(factory).oracleRelayer());
  }

  // NOTE: global parameters are stored/modified in the factory
  function _modifyParameters(bytes32, bytes memory) internal pure override {
    revert UnrecognizedParam();
  }

  function _isAuthorized(address _account)
    internal
    view
    override(AuthorizableChild, Authorizable)
    returns (bool _authorized)
  {
    return super._isAuthorized(_account);
  }
}
