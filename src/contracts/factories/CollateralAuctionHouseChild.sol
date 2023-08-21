// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouseChild} from '@interfaces/factories/ICollateralAuctionHouseChild.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';

import {AuthorizableChild, Authorizable} from '@contracts/factories/AuthorizableChild.sol';
import {DisableableChild, Disableable} from '@contracts/factories/DisableableChild.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

/**
 * @title  CollateralAuctionHouseChild
 * @notice This contract inherits all the functionality of `CollateralAuctionHouse.sol` to be factory deployed
 */
contract CollateralAuctionHouseChild is
  DisableableChild,
  AuthorizableChild,
  CollateralAuctionHouse,
  ICollateralAuctionHouseChild
{
  using EnumerableSet for EnumerableSet.AddressSet;
  using Math for uint256;

  // --- Init ---
  constructor(
    address _safeEngine,
    address _liquidationEngine,
    address _oracleRelayer,
    bytes32 _cType,
    CollateralAuctionHouseParams memory _cahParams
  )
    CollateralAuctionHouse(
      _safeEngine,
      _liquidationEngine, // empty
      _oracleRelayer, // empty
      _cType,
      _cahParams
    )
  {}

  // NOTE: child implementation reads liquidationEngine from factory
  function liquidationEngine()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
    returns (ILiquidationEngine _liquidationEngine)
  {
    return ILiquidationEngine(ICollateralAuctionHouseFactory(factory).liquidationEngine());
  }

  // NOTE: child implementation reads oracleRelayer from factory
  function oracleRelayer()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
    returns (IOracleRelayer _oracleRelayer)
  {
    return IOracleRelayer(ICollateralAuctionHouseFactory(factory).oracleRelayer());
  }

  // NOTE: ignores modifying liquidationEngine's address (read from factory)
  function _setLiquidationEngine(address _newLiquidationEngine) internal override {}
  // NOTE: ignores modifying oracleRelayer's address (read from factory)
  function _setOracleRelayer(address _newLiquidationEngine) internal override {}

  function _isAuthorized(address _account)
    internal
    view
    override(AuthorizableChild, Authorizable)
    returns (bool _authorized)
  {
    return super._isAuthorized(_account);
  }

  function _isEnabled() internal view override(DisableableChild, Disableable) returns (bool _enabled) {
    return super._isEnabled();
  }

  function _onContractDisable() internal override(DisableableChild, Disableable) {
    super._onContractDisable();
  }
}
