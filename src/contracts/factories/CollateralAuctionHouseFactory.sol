// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';

import {CollateralAuctionHouseChild} from '@contracts/factories/CollateralAuctionHouseChild.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';
import {Modifiable, IModifiable} from '@contracts/utils/Modifiable.sol';
import {IModifiablePerCollateral, ModifiablePerCollateral} from '@contracts/utils/ModifiablePerCollateral.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  CollateralAuctionHouseFactory
 * @notice This contract is used to deploy CollateralAuctionHouse contracts
 * @dev    The deployed contracts are CollateralAuctionHouseChild instances
 */
contract CollateralAuctionHouseFactory is
  Authorizable,
  Modifiable,
  ModifiablePerCollateral,
  Disableable,
  ICollateralAuctionHouseFactory
{
  using Assertions for uint256;
  using Assertions for address;
  using Encoding for bytes;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Registry ---

  /// @inheritdoc ICollateralAuctionHouseFactory
  address public safeEngine;
  /// @inheritdoc ICollateralAuctionHouseFactory
  address public liquidationEngine;
  /// @inheritdoc ICollateralAuctionHouseFactory
  address public oracleRelayer;

  // --- Data ---

  /// @inheritdoc ICollateralAuctionHouseFactory
  function cParams(bytes32 _cType)
    external
    view
    returns (ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams)
  {
    return ICollateralAuctionHouse(collateralAuctionHouses[_cType]).params();
  }

  /// @inheritdoc ICollateralAuctionHouseFactory
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (uint256 _minimumBid, uint256 _minDiscount, uint256 _maxDiscount, uint256 _perSecondDiscountUpdateRate)
  {
    return ICollateralAuctionHouse(collateralAuctionHouses[_cType])._params();
  }

  /// @inheritdoc ICollateralAuctionHouseFactory
  mapping(bytes32 _cType => address) public collateralAuctionHouses;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _liquidationEngine Address of the LiquidationEngine contract
   * @param  _oracleRelayer Address of the OracleRelayer contract
   * @dev    Adds authorization to the LiquidationEngine (extended to all child contracts)
   */
  constructor(
    address _safeEngine,
    address _liquidationEngine,
    address _oracleRelayer
  ) Authorizable(msg.sender) validParams {
    safeEngine = _safeEngine.assertHasCode();
    _setLiquidationEngine(_liquidationEngine);
    oracleRelayer = _oracleRelayer;
  }

  // --- Views ---

  /// @inheritdoc ICollateralAuctionHouseFactory
  function collateralAuctionHousesList() external view returns (address[] memory _collateralAuctionHousesList) {
    bytes32[] memory __collateralList = _collateralList.values();
    _collateralAuctionHousesList = new address[](__collateralList.length);
    for (uint256 _i; _i < __collateralList.length; ++_i) {
      _collateralAuctionHousesList[_i] = collateralAuctionHouses[__collateralList[_i]];
    }
  }

  // --- Administration ---

  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralParams) internal override whenEnabled {
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams =
      abi.decode(_collateralParams, (ICollateralAuctionHouse.CollateralAuctionHouseParams));

    ICollateralAuctionHouse _collateralAuctionHouse = new CollateralAuctionHouseChild({
      _safeEngine: safeEngine,
      _liquidationEngine: address(0), // read from factory
      _oracleRelayer: address(0), // read from factory
      _cType: _cType,
      _cahParams: _cahParams
      });

    collateralAuctionHouses[_cType] = address(_collateralAuctionHouse);
    emit DeployCollateralAuctionHouse(_cType, address(_collateralAuctionHouse));
  }

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();

    // Registry
    if (_param == 'liquidationEngine') _setLiquidationEngine(_address);
    else if (_param == 'oracleRelayer') oracleRelayer = _address;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    IModifiable(collateralAuctionHouses[_cType]).modifyParameters(_param, _data);
  }

  /// @dev Sets the LiquidationEngine contract address, revoking the previous, and granting the new one authorization
  function _setLiquidationEngine(address _newLiquidationEngine) internal {
    if (liquidationEngine != address(0)) _removeAuthorization(liquidationEngine);
    liquidationEngine = _newLiquidationEngine;
    _addAuthorization(_newLiquidationEngine);
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    liquidationEngine.assertHasCode();
    oracleRelayer.assertHasCode();
  }
}
