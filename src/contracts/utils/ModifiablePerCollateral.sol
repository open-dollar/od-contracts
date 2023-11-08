// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  ModifiablePerCollateral
 * @notice Allows inheriting contracts to modify parameters values and initialize collateral types
 * @dev    Requires inheriting contracts to override `_modifyParameters` virtual methods and implement `_initializeCollateralType`
 */
abstract contract ModifiablePerCollateral is Authorizable, IModifiablePerCollateral {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Data ---
  EnumerableSet.Bytes32Set internal _collateralList;

  // --- Views ---
  /// @inheritdoc IModifiablePerCollateral
  function collateralList() external view returns (bytes32[] memory __collateralList) {
    return _collateralList.values();
  }

  // --- Methods ---

  /// @inheritdoc IModifiablePerCollateral
  function initializeCollateralType(
    bytes32 _cType,
    bytes memory _collateralParams
  ) public virtual isAuthorized validCParams(_cType) {
    if (!_collateralList.add(_cType)) revert CollateralTypeAlreadyInitialized();
    _initializeCollateralType(_cType, _collateralParams);
    emit InitializeCollateralType(_cType);
  }

  /// @inheritdoc IModifiablePerCollateral
  function modifyParameters(
    bytes32 _cType,
    bytes32 _param,
    bytes memory _data
  ) external isAuthorized validCParams(_cType) {
    _modifyParameters(_cType, _param, _data);
    emit ModifyParameters(_param, _cType, _data);
  }

  /**
   * @notice Set a new value for a collateral specific parameter
   * @param _cType String identifier of the collateral to modify
   * @param _param String identifier of the parameter to modify
   * @param _data Encoded data to modify the parameter
   */
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal virtual;

  /**
   * @notice Register a new collateral type in the SAFEEngine
   * @param _cType Collateral type to register
   * @param _collateralParams Collateral parameters
   */
  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralParams) internal virtual;

  /// @notice Internal function to be overriden with custom logic to validate collateral parameters
  function _validateCParameters(bytes32 _cType) internal view virtual {}

  // --- Modifiers ---

  /// @notice Triggers a routine to validate collateral parameters after a modification
  modifier validCParams(bytes32 _cType) {
    _;
    _validateCParameters(_cType);
  }
}
