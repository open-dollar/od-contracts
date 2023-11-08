// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralAuctionHouseChild} from '@interfaces/factories/ICollateralAuctionHouseChild.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';

import {AuthorizableChild, Authorizable} from '@contracts/factories/AuthorizableChild.sol';
import {DisableableChild, Disableable} from '@contracts/factories/DisableableChild.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  CollateralAuctionHouseChild
 * @notice This contract inherits all the functionality of CollateralAuctionHouse to be factory deployed
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

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _liquidationEngine Ignored parameter (read from factory)
   * @param  _oracleRelayer Ignored parameter (read from factory)
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _cahParams Initial valid CollateralAuctionHouse parameters struct
   */
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

  // --- Overrides ---

  /**
   * @dev Overriding method reads liquidationEngine from factory
   * @inheritdoc ICollateralAuctionHouse
   */
  function liquidationEngine()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
    returns (ILiquidationEngine _liquidationEngine)
  {
    return ILiquidationEngine(ICollateralAuctionHouseFactory(factory).liquidationEngine());
  }

  /**
   * @dev Overriding method reads oracleRelayer from factory
   * @inheritdoc ICollateralAuctionHouse
   */
  function oracleRelayer()
    public
    view
    override(CollateralAuctionHouse, ICollateralAuctionHouse)
    returns (IOracleRelayer _oracleRelayer)
  {
    return IOracleRelayer(ICollateralAuctionHouseFactory(factory).oracleRelayer());
  }

  /**
   * @dev    Modifying liquidationEngine's address results in a no-operation (is read from factory)
   * @param  _newLiquidationEngine Ignored parameter (read from factory)
   * @inheritdoc CollateralAuctionHouse
   */
  function _setLiquidationEngine(address _newLiquidationEngine) internal override {}

  /**
   * @dev    Modifying oracleRelayer's address results in a no-operation (is read from factory)
   * @param  _newOracleRelayer Ignored parameter (read from factory)
   * @inheritdoc CollateralAuctionHouse
   */
  function _setOracleRelayer(address _newOracleRelayer) internal override {}

  /// @inheritdoc AuthorizableChild
  function _isAuthorized(address _account)
    internal
    view
    override(AuthorizableChild, Authorizable)
    returns (bool _authorized)
  {
    return super._isAuthorized(_account);
  }

  /// @inheritdoc DisableableChild
  function _isEnabled() internal view override(DisableableChild, Disableable) returns (bool _enabled) {
    return super._isEnabled();
  }

  /// @inheritdoc DisableableChild
  function _onContractDisable() internal override(DisableableChild, Disableable) {
    super._onContractDisable();
  }
}
