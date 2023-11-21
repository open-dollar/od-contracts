// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {ModifiablePerCollateral} from '@contracts/utils/ModifiablePerCollateral.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  TaxCollector
 * @notice This contract calculates and collects the stability fee from all collateral types
 */
contract TaxCollector is Authorizable, Modifiable, ModifiablePerCollateral, ITaxCollector {
  using Math for uint256;
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Registry ---

  /// @inheritdoc ITaxCollector
  ISAFEEngine public safeEngine;

  // --- Data ---

  /// @inheritdoc ITaxCollector
  // solhint-disable-next-line private-vars-leading-underscore
  TaxCollectorParams public _params;

  /// @inheritdoc ITaxCollector
  function params() external view returns (TaxCollectorParams memory _taxCollectorParams) {
    return _params;
  }

  /// @inheritdoc ITaxCollector
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => TaxCollectorCollateralParams) public _cParams;

  /// @inheritdoc ITaxCollector
  function cParams(bytes32 _cType) external view returns (TaxCollectorCollateralParams memory _taxCollectorCParams) {
    return _cParams[_cType];
  }

  /// @inheritdoc ITaxCollector
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => TaxCollectorCollateralData) public _cData;

  /// @inheritdoc ITaxCollector
  function cData(bytes32 _cType) external view returns (TaxCollectorCollateralData memory _taxCollectorCData) {
    return _cData[_cType];
  }

  /// @notice List of collateral types that send SF to a specific tax receiver
  mapping(address _taxReceiver => EnumerableSet.Bytes32Set) internal _secondaryReceiverRevenueSources;

  /// @inheritdoc ITaxCollector
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => mapping(address _taxReceiver => TaxReceiver)) public _secondaryTaxReceivers;

  /// @inheritdoc ITaxCollector
  function secondaryTaxReceivers(
    bytes32 _cType,
    address _receiver
  ) external view returns (TaxReceiver memory _secondaryTaxReceiver) {
    return _secondaryTaxReceivers[_cType][_receiver];
  }

  /// @notice Enumerable set with the active secondary tax receivers
  EnumerableSet.AddressSet internal _secondaryReceivers;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _taxCollectorParams Initial valid TaxCollector parameters struct
   */
  constructor(address _safeEngine, TaxCollectorParams memory _taxCollectorParams) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    _params = _taxCollectorParams;
    _setPrimaryTaxReceiver(_taxCollectorParams.primaryTaxReceiver);
  }

  // --- Tax Collection Utils ---

  /// @inheritdoc ITaxCollector
  function collectedManyTax(uint256 _start, uint256 _end) public view returns (bool _ok) {
    if (_start > _end || _end >= _collateralList.length()) revert TaxCollector_InvalidIndexes();
    for (uint256 _i = _start; _i <= _end; ++_i) {
      if (block.timestamp > _cData[_collateralList.at(_i)].updateTime) {
        _ok = false;
        return _ok;
      }
    }
    _ok = true;
  }

  /// @inheritdoc ITaxCollector
  function taxManyOutcome(uint256 _start, uint256 _end) public view returns (bool _ok, int256 _rad) {
    if (_start > _end || _end >= _collateralList.length()) revert TaxCollector_InvalidIndexes();
    int256 _primaryReceiverBalance = -safeEngine.coinBalance(_params.primaryTaxReceiver).toInt();
    int256 _deltaRate;
    uint256 _debtAmount;

    bytes32 _cType;
    for (uint256 _i = _start; _i <= _end; ++_i) {
      _cType = _collateralList.at(_i);

      if (block.timestamp > _cData[_cType].updateTime) {
        _debtAmount = safeEngine.cData(_cType).debtAmount;
        (, _deltaRate) = taxSingleOutcome(_cType);
        _rad = _rad + _debtAmount.mul(_deltaRate);
      }
    }
    _ok = _rad >= 0 || _rad >= _primaryReceiverBalance;
  }

  /// @inheritdoc ITaxCollector
  function taxSingleOutcome(bytes32 _cType) public view returns (uint256 _newlyAccumulatedRate, int256 _deltaRate) {
    uint256 _lastAccumulatedRate = safeEngine.cData(_cType).accumulatedRate;

    TaxCollectorCollateralData memory __cData = _cData[_cType];
    _newlyAccumulatedRate =
      __cData.nextStabilityFee.rpow(block.timestamp - __cData.updateTime).rmul(_lastAccumulatedRate);
    return (_newlyAccumulatedRate, _newlyAccumulatedRate.sub(_lastAccumulatedRate));
  }

  // --- Tax Receiver Utils ---

  /// @inheritdoc ITaxCollector
  function secondaryReceiversListLength() public view returns (uint256 _secondaryReceiversListLength) {
    return _secondaryReceivers.length();
  }

  /// @inheritdoc ITaxCollector
  function collateralListLength() public view returns (uint256 _collateralListLength) {
    return _collateralList.length();
  }

  /// @inheritdoc ITaxCollector
  function isSecondaryReceiver(address _receiver) public view returns (bool _isSecondaryReceiver) {
    return _secondaryReceivers.contains(_receiver);
  }

  // --- Views ---

  /// @inheritdoc ITaxCollector
  function secondaryReceiversList() external view returns (address[] memory _secondaryReceiversList) {
    return _secondaryReceivers.values();
  }

  /// @inheritdoc ITaxCollector
  function secondaryReceiverRevenueSourcesList(address _secondaryReceiver)
    external
    view
    returns (bytes32[] memory _secondaryReceiverRevenueSourcesList)
  {
    return _secondaryReceiverRevenueSources[_secondaryReceiver].values();
  }

  // --- Tax (Stability Fee) Collection ---

  /// @inheritdoc ITaxCollector
  function taxMany(uint256 _start, uint256 _end) external {
    if (_start > _end || _end >= _collateralList.length()) revert TaxCollector_InvalidIndexes();
    for (uint256 _i = _start; _i <= _end; ++_i) {
      taxSingle(_collateralList.at(_i));
    }
  }

  /// @inheritdoc ITaxCollector
  function taxSingle(bytes32 _cType) public returns (uint256 _latestAccumulatedRate) {
    TaxCollectorCollateralData memory __cData = _cData[_cType];

    if (block.timestamp == __cData.updateTime) {
      _latestAccumulatedRate = safeEngine.cData(_cType).accumulatedRate;
      _cData[_cType].nextStabilityFee = _getNextStabilityFee(_cType);
      return _latestAccumulatedRate;
    }
    (, int256 _deltaRate) = taxSingleOutcome(_cType);
    // Check how much debt has been generated for collateralType
    uint256 _debtAmount = safeEngine.cData(_cType).debtAmount;
    _splitTaxIncome(_cType, _debtAmount, _deltaRate);
    _latestAccumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    __cData.updateTime = block.timestamp;
    __cData.nextStabilityFee = _getNextStabilityFee(_cType);
    _cData[_cType] = __cData;

    emit CollectTax(_cType, _latestAccumulatedRate, _deltaRate);
    return _latestAccumulatedRate;
  }

  /**
   * @notice Compute the next stability fee for a collateral type, bounded by the maxStabilityFeeRange
   * @param  _cType Bytes32 identifier of the collateral type
   * @return _nextStabilityFee The next stability fee to be applied for the collateral type
   * @dev    The stability fee calculation is bounded by the maxStabilityFeeRange
   */
  function _getNextStabilityFee(bytes32 _cType) internal view returns (uint256 _nextStabilityFee) {
    _nextStabilityFee = _params.globalStabilityFee.rmul(_cParams[_cType].stabilityFee);
    if (_nextStabilityFee < RAY - _params.maxStabilityFeeRange) return RAY - _params.maxStabilityFeeRange;
    if (_nextStabilityFee > RAY + _params.maxStabilityFeeRange) return RAY + _params.maxStabilityFeeRange;
  }

  /**
   * @notice Split SF between all tax receivers
   * @param  _cType Collateral type to distribute SF for
   * @param  _debtAmount Total debt currently issued for the collateral type
   * @param  _deltaRate Difference between the last and the latest accumulate rates for the collateralType
   */
  function _splitTaxIncome(bytes32 _cType, uint256 _debtAmount, int256 _deltaRate) internal {
    // Start looping from the oldest tax receiver
    address _secondaryReceiver;
    uint256 _secondaryReceiversListLength = _secondaryReceivers.length();
    // Loop through the entire tax receiver list
    for (uint256 _i; _i < _secondaryReceiversListLength; ++_i) {
      _secondaryReceiver = _secondaryReceivers.at(_i);
      // If the current tax receiver should receive SF from collateralType
      if (_secondaryReceiverRevenueSources[_secondaryReceiver].contains(_cType)) {
        _distributeTax(_cType, _secondaryReceiver, _debtAmount, _deltaRate);
      }
    }
    // Distribute to primary receiver
    _distributeTax(_cType, _params.primaryTaxReceiver, _debtAmount, _deltaRate);
  }

  /**
   * @notice Give/withdraw SF from a tax receiver
   * @param  _cType Collateral type to distribute SF for
   * @param  _receiver Tax receiver address
   * @param  _debtAmount Total debt currently issued
   * @param  _deltaRate Difference between the latest and the last accumulated rates for the collateralType
   */
  function _distributeTax(bytes32 _cType, address _receiver, uint256 _debtAmount, int256 _deltaRate) internal {
    // Check how many coins the receiver has and negate the value
    int256 _coinBalance = -safeEngine.coinBalance(_receiver).toInt();
    int256 __debtAmount = _debtAmount.toInt();

    TaxReceiver memory _taxReceiver = _secondaryTaxReceivers[_cType][_receiver];
    // Compute the % out of SF that should be allocated to the receiver
    int256 _currentTaxCut = _receiver == _params.primaryTaxReceiver
      ? (WAD - _cData[_cType].secondaryReceiverAllotedTax).wmul(_deltaRate)
      : _taxReceiver.taxPercentage.wmul(_deltaRate);

    /**
     * If SF is negative and a tax receiver doesn't have enough coins to absorb the loss,
     *           compute a new tax cut that can be absorbed
     */
    _currentTaxCut = __debtAmount * _currentTaxCut < 0 && _coinBalance > __debtAmount * _currentTaxCut
      ? _coinBalance / __debtAmount
      : _currentTaxCut;

    /**
     * If the tax receiver's tax cut is not null and if the receiver accepts negative SF
     *         offer/take SF to/from them
     */
    if (_currentTaxCut != 0) {
      if (_receiver == _params.primaryTaxReceiver || (_deltaRate >= 0 || _taxReceiver.canTakeBackTax)) {
        safeEngine.updateAccumulatedRate(_cType, _receiver, _currentTaxCut);
        emit DistributeTax(_cType, _receiver, _currentTaxCut);
      }
    }
  }

  // --- Administration ---

  /// @inheritdoc ModifiablePerCollateral
  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralParams) internal override {
    TaxCollectorCollateralParams memory _taxCollectorCParams =
      abi.decode(_collateralParams, (TaxCollectorCollateralParams));
    _cData[_cType] =
      TaxCollectorCollateralData({nextStabilityFee: RAY, updateTime: block.timestamp, secondaryReceiverAllotedTax: 0});
    _cParams[_cType] = _taxCollectorCParams;
  }

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'primaryTaxReceiver') _setPrimaryTaxReceiver(_data.toAddress());
    else if (_param == 'globalStabilityFee') _params.globalStabilityFee = _uint256;
    else if (_param == 'maxStabilityFeeRange') _params.maxStabilityFeeRange = _uint256;
    else if (_param == 'maxSecondaryReceivers') _params.maxSecondaryReceivers = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    if (_param == 'stabilityFee') _cParams[_cType].stabilityFee = _data.toUint256();
    else if (_param == 'secondaryTaxReceiver') _setSecondaryTaxReceiver(_cType, abi.decode(_data, (TaxReceiver)));
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    _params.primaryTaxReceiver.assertNonNull();
    _params.maxStabilityFeeRange.assertGt(0).assertLt(RAY);
    _params.globalStabilityFee.assertGtEq(RAY - _params.maxStabilityFeeRange).assertLtEq(
      RAY + _params.maxStabilityFeeRange
    );
  }

  /// @inheritdoc ModifiablePerCollateral
  function _validateCParameters(bytes32 _cType) internal view override {
    _cParams[_cType].stabilityFee.assertGtEq(RAY - _params.maxStabilityFeeRange).assertLtEq(
      RAY + _params.maxStabilityFeeRange
    );
  }

  /**
   * @notice Sets the primary tax receiver, the address that receives the unallocated SF from all collateral types
   * @param  _primaryTaxReceiver Address of the primary tax receiver
   */
  function _setPrimaryTaxReceiver(address _primaryTaxReceiver) internal {
    _params.primaryTaxReceiver = _primaryTaxReceiver;
    emit SetPrimaryReceiver(_GLOBAL_PARAM, _primaryTaxReceiver);
  }

  /**
   * @notice Add a new secondary tax receiver or update data (add a new SF source or modify % of SF taken from a collateral type)
   * @param  _cType Collateral type that will give SF to the tax receiver
   * @param  _data Encoded data containing the receiver, tax percentage, and whether it supports negative tax
   */
  function _setSecondaryTaxReceiver(bytes32 _cType, TaxReceiver memory _data) internal {
    if (_data.receiver == address(0)) revert TaxCollector_NullAccount();
    if (_data.receiver == _params.primaryTaxReceiver) revert TaxCollector_PrimaryReceiverCannotBeSecondary();
    if (!_collateralList.contains(_cType)) revert TaxCollector_CollateralTypeNotInitialized();

    if (_secondaryReceivers.add(_data.receiver)) {
      // receiver is a new secondary receiver

      if (_secondaryReceivers.length() > _params.maxSecondaryReceivers) revert TaxCollector_ExceedsMaxReceiverLimit();
      if (_data.taxPercentage == 0) revert TaxCollector_NullSF();
      if (_cData[_cType].secondaryReceiverAllotedTax + _data.taxPercentage > WAD) {
        revert TaxCollector_TaxCutExceedsHundred();
      }

      _cData[_cType].secondaryReceiverAllotedTax += _data.taxPercentage;
      _secondaryReceiverRevenueSources[_data.receiver].add(_cType);
      _secondaryTaxReceivers[_cType][_data.receiver] = _data;
    } else {
      // receiver is already a secondary receiver

      if (_data.taxPercentage == 0) {
        // deletes the existing receiver

        _cData[_cType].secondaryReceiverAllotedTax -= _secondaryTaxReceivers[_cType][_data.receiver].taxPercentage;

        _secondaryReceiverRevenueSources[_data.receiver].remove(_cType);
        if (_secondaryReceiverRevenueSources[_data.receiver].length() == 0) {
          _secondaryReceivers.remove(_data.receiver);
        }

        delete(_secondaryTaxReceivers[_cType][_data.receiver]);
      } else {
        // modifies the information on the existing receiver

        uint256 _secondaryReceiverAllotedTax = (
          _cData[_cType].secondaryReceiverAllotedTax - _secondaryTaxReceivers[_cType][_data.receiver].taxPercentage
        ) + _data.taxPercentage;
        if (_secondaryReceiverAllotedTax > WAD) revert TaxCollector_TaxCutTooBig();

        _cData[_cType].secondaryReceiverAllotedTax = _secondaryReceiverAllotedTax;
        _secondaryTaxReceivers[_cType][_data.receiver] = _data;
        // NOTE: if it was already added it just ignores it
        _secondaryReceiverRevenueSources[_data.receiver].add(_cType);
      }
    }

    emit SetSecondaryReceiver(_cType, _data.receiver, _data.taxPercentage, _data.canTakeBackTax);
  }
}
