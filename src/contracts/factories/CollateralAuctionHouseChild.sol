// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouseChild} from '@interfaces/factories/ICollateralAuctionHouseChild.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';

import {AuthorizableChild, Authorizable} from '@contracts/factories/AuthorizableChild.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

/**
 * @title  CollateralAuctionHouseChild
 * @notice This contract inherits all the functionality of `CollateralAuctionHouse.sol` to be factory deployed
 */
contract CollateralAuctionHouseChild is AuthorizableChild, CollateralAuctionHouse, ICollateralAuctionHouseChild {
  using EnumerableSet for EnumerableSet.AddressSet;
  using Math for uint256;

  // --- Init ---
  constructor(
    address _safeEngine,
    address _oracleRelayer,
    address _liquidationEngine,
    bytes32 _cType,
    CollateralAuctionHouseSystemCoinParams memory _cahParams,
    CollateralAuctionHouseParams memory _cahCParams
  )
    CollateralAuctionHouse(
      _safeEngine,
      _oracleRelayer, // empty
      _liquidationEngine, // empty
      _cType,
      _cahParams, // empty
      _cahCParams
    )
  {}

  // NOTE: child implementation reads params from factory
  function params()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
    returns (CollateralAuctionHouseSystemCoinParams memory _cahParams)
  {
    return ICollateralAuctionHouseFactory(factory).params();
  }

  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
    returns (uint256 _minSystemCoinDeviation, uint256 _lowerSystemCoinDeviation, uint256 _upperSystemCoinDeviation)
  {
    return ICollateralAuctionHouseFactory(factory)._params();
  }

  // NOTE: child implementation reads liquidationEngine from factory
  function liquidationEngine()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
    returns (ILiquidationEngine _liquidationEngine)
  {
    return ILiquidationEngine(ICollateralAuctionHouseFactory(factory).liquidationEngine());
  }

  // NOTE: avoids adding authorization to address(0) on constructor
  function _setLiquidationEngine(address _newLiquidationEngine) internal override {}

  // NOTE: child implementation reads oracleRelayer from factory
  function oracleRelayer()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
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
