// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {ModifiablePerCollateral} from '@contracts/utils/ModifiablePerCollateral.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

/**
 * @title  OracleRelayer
 * @notice Handles the collateral prices inside the system (SAFEEngine) and calculates the redemption price using the rate
 */
contract OracleRelayer is Authorizable, Disableable, Modifiable, ModifiablePerCollateral, IOracleRelayer {
  using Encoding for bytes;
  using Math for uint256;
  using Assertions for uint256;
  using Assertions for address;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Registry ---

  /// @inheritdoc IOracleRelayer
  ISAFEEngine public safeEngine;
  /// @inheritdoc IOracleRelayer
  IBaseOracle public systemCoinOracle;

  // --- Params ---
  /// @inheritdoc IOracleRelayer
  // solhint-disable-next-line private-vars-leading-underscore
  OracleRelayerParams public _params;
  /// @inheritdoc IOracleRelayer
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => OracleRelayerCollateralParams) public _cParams;

  /// @inheritdoc IOracleRelayer
  function params() external view override returns (OracleRelayerParams memory _oracleRelayerParams) {
    return _params;
  }

  /// @inheritdoc IOracleRelayer
  function cParams(bytes32 _cType) external view returns (OracleRelayerCollateralParams memory _oracleRelayerCParams) {
    return _cParams[_cType];
  }

  /// @dev Virtual redemption price (not the most updated value) [ray]
  uint256 internal /* RAY */ _redemptionPrice;
  /// @inheritdoc IOracleRelayer
  uint256 public /* RAY */ redemptionRate;
  /// @inheritdoc IOracleRelayer
  uint256 public redemptionPriceUpdateTime;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine
   * @param  _systemCoinOracle Address of the system coin oracle
   * @param  _oracleRelayerParams Initial OracleRelayer valid parameters struct
   */
  constructor(
    address _safeEngine,
    IBaseOracle _systemCoinOracle,
    OracleRelayerParams memory _oracleRelayerParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    systemCoinOracle = _systemCoinOracle;
    _redemptionPrice = RAY;
    redemptionRate = RAY;
    redemptionPriceUpdateTime = block.timestamp;
    _params = _oracleRelayerParams;
  }

  /// @inheritdoc IOracleRelayer
  function marketPrice() external view returns (uint256 _marketPrice) {
    (uint256 _priceFeedValue, bool _hasValidValue) = systemCoinOracle.getResultWithValidity();
    if (_hasValidValue) return _priceFeedValue;
  }

  /**
   * @dev To be used within view functions, not to be used in transactions, use `redemptionPrice` instead
   * @inheritdoc IOracleRelayer
   */
  function calcRedemptionPrice() external view returns (uint256 _virtualRedemptionPrice) {
    return redemptionRate.rpow(block.timestamp - redemptionPriceUpdateTime).rmul(_redemptionPrice);
  }

  // --- Redemption Price Update ---

  /// @notice Calculates and updates the redemption price using the current redemption rate
  function _updateRedemptionPrice() internal virtual returns (uint256 _updatedPrice) {
    // Update redemption price
    _updatedPrice = redemptionRate.rpow(block.timestamp - redemptionPriceUpdateTime).rmul(_redemptionPrice);
    if (_updatedPrice == 0) _updatedPrice = 1;
    _redemptionPrice = _updatedPrice;
    redemptionPriceUpdateTime = block.timestamp;
    emit UpdateRedemptionPrice(_updatedPrice);
  }

  /// @inheritdoc IOracleRelayer
  function redemptionPrice() external returns (uint256 _updatedPrice) {
    return _getRedemptionPrice();
  }

  /// @dev Avoids reupdating the redemptionPrice if no seconds have passed since last update
  function _getRedemptionPrice() internal virtual returns (uint256 _updatedPrice) {
    if (block.timestamp > redemptionPriceUpdateTime) return _updateRedemptionPrice();
    return _redemptionPrice;
  }

  // --- Update value ---

  /// @inheritdoc IOracleRelayer
  function updateCollateralPrice(bytes32 _cType) external whenEnabled {
    (uint256 _priceFeedValue, bool _hasValidValue) = _cParams[_cType].oracle.getResultWithValidity();
    uint256 _updatedRedemptionPrice = _getRedemptionPrice();

    uint256 _safetyPrice =
      _hasValidValue ? (_priceFeedValue * 1e9).rdiv(_updatedRedemptionPrice).rdiv(_cParams[_cType].safetyCRatio) : 0;

    uint256 _liquidationPrice = _hasValidValue
      ? (_priceFeedValue * 1e9).rdiv(_updatedRedemptionPrice).rdiv(_cParams[_cType].liquidationCRatio)
      : 0;

    safeEngine.updateCollateralPrice(_cType, _safetyPrice, _liquidationPrice);
    emit UpdateCollateralPrice(_cType, _priceFeedValue, _safetyPrice, _liquidationPrice);
  }

  /// @inheritdoc IOracleRelayer
  function updateRedemptionRate(uint256 _redemptionRate) external isAuthorized whenEnabled {
    if (block.timestamp != redemptionPriceUpdateTime) revert OracleRelayer_RedemptionPriceNotUpdated();

    if (_redemptionRate > _params.redemptionRateUpperBound) {
      _redemptionRate = _params.redemptionRateUpperBound;
    } else if (_redemptionRate < _params.redemptionRateLowerBound) {
      _redemptionRate = _params.redemptionRateLowerBound;
    }
    redemptionRate = _redemptionRate;
  }

  // --- Shutdown ---
  /**
   * @dev Sets the redemption rate to 1 (no change in the redemption price)
   * @inheritdoc Disableable
   */
  function _onContractDisable() internal override {
    redemptionRate = RAY;
  }

  // --- Administration ---

  /// @inheritdoc ModifiablePerCollateral
  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralParams) internal override {
    (OracleRelayerCollateralParams memory _oracleRelayerCParams) =
      abi.decode(_collateralParams, (OracleRelayerCollateralParams));
    address(_oracleRelayerCParams.oracle).assertHasCode();
    _cParams[_cType] = _oracleRelayerCParams;
  }

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override whenEnabled {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'systemCoinOracle') systemCoinOracle = IBaseOracle(_data.toAddress().assertHasCode());
    else if (_param == 'redemptionRateUpperBound') _params.redemptionRateUpperBound = _uint256;
    else if (_param == 'redemptionRateLowerBound') _params.redemptionRateLowerBound = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override whenEnabled {
    uint256 _uint256 = _data.toUint256();
    OracleRelayerCollateralParams storage __cParams = _cParams[_cType];

    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    if (_param == 'safetyCRatio') __cParams.safetyCRatio = _uint256;
    else if (_param == 'liquidationCRatio') __cParams.liquidationCRatio = _uint256;
    else if (_param == 'oracle') __cParams.oracle = IBaseOracle(_data.toAddress().assertHasCode());
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    _params.redemptionRateUpperBound.assertGt(RAY);
    _params.redemptionRateLowerBound.assertGt(0).assertLt(RAY);
    address(systemCoinOracle).assertHasCode();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _validateCParameters(bytes32 _cType) internal view override {
    OracleRelayerCollateralParams memory __cParams = _cParams[_cType];
    __cParams.safetyCRatio.assertGtEq(__cParams.liquidationCRatio);
    __cParams.liquidationCRatio.assertGtEq(RAY);
    address(__cParams.oracle).assertHasCode();
  }
}
