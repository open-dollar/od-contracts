// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/*

Coded for Reflexer and The Money God with 🥕 by

░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░░
░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗░
░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║░
░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║░
░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝░
░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░░

https://defi.sucks

*/

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {IModifiablePerCollateral, ModifiablePerCollateral} from '@contracts/utils/ModifiablePerCollateral.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  SAFEEngine
 * @notice Core contract that manages the state of the SAFE system
 */
contract SAFEEngine is Authorizable, Disableable, Modifiable, ModifiablePerCollateral, ISAFEEngine {
  using Math for uint256;
  using Encoding for bytes;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Data ---

  /// @inheritdoc ISAFEEngine
  // solhint-disable-next-line private-vars-leading-underscore
  SAFEEngineParams public _params;
  /// @inheritdoc ISAFEEngine
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => SAFEEngineCollateralParams) public _cParams;
  /// @inheritdoc ISAFEEngine
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => SAFEEngineCollateralData) public _cData;
  /// @inheritdoc ISAFEEngine
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => mapping(address _safe => SAFE)) public _safes;
  /// @inheritdoc ISAFEEngine
  mapping(address _caller => mapping(address _account => bool _isAllowed)) public safeRights;

  /// @inheritdoc ISAFEEngine
  function params() external view returns (SAFEEngineParams memory _safeEngineParams) {
    return _params;
  }

  /// @inheritdoc ISAFEEngine
  function cParams(bytes32 _cType) external view returns (SAFEEngineCollateralParams memory _safeEngineCParams) {
    return _cParams[_cType];
  }

  /// @inheritdoc ISAFEEngine
  function cData(bytes32 _cType) external view returns (SAFEEngineCollateralData memory _safeEngineCData) {
    return _cData[_cType];
  }

  /// @inheritdoc ISAFEEngine
  function safes(bytes32 _cType, address _safe) external view returns (SAFE memory _safeData) {
    return _safes[_cType][_safe];
  }

  // --- Balances ---

  /// @inheritdoc ISAFEEngine
  mapping(bytes32 _cType => mapping(address _safe => uint256 _wad)) public tokenCollateral;
  /// @inheritdoc ISAFEEngine
  mapping(address _safe => uint256 _rad) public coinBalance;
  /// @inheritdoc ISAFEEngine
  mapping(address _safe => uint256 _rad) public debtBalance;
  /// @inheritdoc ISAFEEngine
  uint256 public /* RAD */ globalDebt;
  /// @inheritdoc ISAFEEngine
  uint256 public /* RAD */ globalUnbackedDebt;

  // --- Init ---

  /**
   * @param  _safeEngineParams Initial SAFEEngine valid parameters struct
   */
  constructor(SAFEEngineParams memory _safeEngineParams) Authorizable(msg.sender) validParams {
    _params = _safeEngineParams;
  }

  // --- Fungibility ---

  /// @inheritdoc ISAFEEngine
  function transferCollateral(
    bytes32 _cType,
    address _source,
    address _destination,
    uint256 _wad
  ) external isSAFEAllowed(_source, msg.sender) {
    tokenCollateral[_cType][_source] -= _wad;
    tokenCollateral[_cType][_destination] += _wad;
    emit TransferCollateral(_cType, _source, _destination, _wad);
  }

  /// @inheritdoc ISAFEEngine
  function transferInternalCoins(
    address _source,
    address _destination,
    uint256 _rad
  ) external isSAFEAllowed(_source, msg.sender) {
    coinBalance[_source] -= _rad;
    coinBalance[_destination] += _rad;
    emit TransferInternalCoins(_source, _destination, _rad);
  }

  /// @inheritdoc ISAFEEngine
  function modifyCollateralBalance(bytes32 _cType, address _account, int256 _wad) external isAuthorized {
    _modifyCollateralBalance(_cType, _account, _wad);
  }

  // --- SAFE Manipulation ---

  /// @inheritdoc ISAFEEngine
  function modifySAFECollateralization(
    bytes32 _cType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external whenEnabled {
    SAFEEngineCollateralData storage __cData = _cData[_cType];
    // collateral type has been initialised
    if (__cData.accumulatedRate == 0) revert SAFEEng_CollateralTypeNotInitialized();

    _modifyCollateralBalance(_cType, _collateralSource, -_deltaCollateral);
    _emitTransferCollateral(_cType, address(0), _safe, _deltaCollateral);
    _modifySAFECollateralization(_cType, _safe, _deltaCollateral, _deltaDebt);
    __cData.debtAmount = __cData.debtAmount.add(_deltaDebt);
    __cData.lockedAmount = __cData.lockedAmount.add(_deltaCollateral);

    int256 _deltaAdjustedDebt = __cData.accumulatedRate.mul(_deltaDebt);
    _modifyInternalCoins(_debtDestination, _deltaAdjustedDebt);

    // --- Safety checks ---
    {
      SAFEEngineCollateralParams memory __cParams = _cParams[_cType];
      SAFE memory _safeData = _safes[_cType][_safe];
      uint256 _totalDebtIssued = __cData.accumulatedRate * _safeData.generatedDebt;

      // either debt is increased (generated) and debt ceilings are not exceeded, or debt destination consents
      if (_deltaDebt > 0) {
        if (globalDebt > _params.globalDebtCeiling) revert SAFEEng_GlobalDebtCeilingHit();
        if (__cData.debtAmount * __cData.accumulatedRate > __cParams.debtCeiling) {
          revert SAFEEng_CollateralDebtCeilingHit();
        }
        if (_safeData.generatedDebt > _params.safeDebtCeiling) revert SAFEEng_SAFEDebtCeilingHit();
      } else {
        if (!canModifySAFE(_debtDestination, msg.sender)) revert SAFEEng_NotDebtDstAllowed();
      }

      // either safe is less risky, or it is still safe and the owner consents
      if (_deltaDebt > 0 || _deltaCollateral < 0) {
        if (_totalDebtIssued > _safeData.lockedCollateral * __cData.safetyPrice) revert SAFEEng_SAFENotSafe();
        if (!canModifySAFE(_safe, msg.sender)) revert SAFEEng_NotSAFEAllowed();
      }

      // either collateral is decreased (returned), or collateral source consents
      if (_deltaCollateral > 0) {
        if (!canModifySAFE(_collateralSource, msg.sender)) revert SAFEEng_NotCollateralSrcAllowed();
      }

      // either safe has no debt, or a non-dusty amount
      if (_safeData.generatedDebt != 0 && _totalDebtIssued < __cParams.debtFloor) revert SAFEEng_DustySAFE();
    }

    emit ModifySAFECollateralization(_cType, _safe, _collateralSource, _debtDestination, _deltaCollateral, _deltaDebt);
  }

  // --- SAFE Fungibility ---

  /// @inheritdoc ISAFEEngine
  function transferSAFECollateralAndDebt(
    bytes32 _cType,
    address _src,
    address _dst,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external isSAFEAllowed(_src, msg.sender) isSAFEAllowed(_dst, msg.sender) {
    _modifySAFECollateralization(_cType, _src, -_deltaCollateral, -_deltaDebt);
    _emitTransferCollateral(_cType, _src, _dst, _deltaCollateral);
    _modifySAFECollateralization(_cType, _dst, _deltaCollateral, _deltaDebt);

    // --- Safety checks ---
    {
      SAFE memory _srcSAFE = _safes[_cType][_src];
      SAFE memory _dstSAFE = _safes[_cType][_dst];
      SAFEEngineCollateralParams memory __cParams = _cParams[_cType];
      SAFEEngineCollateralData memory __cData = _cData[_cType];

      uint256 _srcTotalDebtIssued = _srcSAFE.generatedDebt * __cData.accumulatedRate;
      uint256 _dstTotalDebtIssued = _dstSAFE.generatedDebt * __cData.accumulatedRate;

      // both sides below debt ceiling
      if (_srcSAFE.generatedDebt > _params.safeDebtCeiling || _dstSAFE.generatedDebt > _params.safeDebtCeiling) {
        revert SAFEEng_SAFEDebtCeilingHit();
      }

      // both sides safe
      if (
        _srcTotalDebtIssued > _srcSAFE.lockedCollateral * __cData.safetyPrice
          || _dstTotalDebtIssued > _dstSAFE.lockedCollateral * __cData.safetyPrice
      ) revert SAFEEng_SAFENotSafe();

      // both sides non-dusty
      if (
        (_srcTotalDebtIssued < __cParams.debtFloor && _srcSAFE.generatedDebt != 0)
          || (_dstTotalDebtIssued < __cParams.debtFloor && _dstSAFE.generatedDebt != 0)
      ) revert SAFEEng_DustySAFE();
    }

    emit TransferSAFECollateralAndDebt(_cType, _src, _dst, _deltaCollateral, _deltaDebt);
  }

  // --- SAFE Confiscation ---

  /// @inheritdoc ISAFEEngine
  function confiscateSAFECollateralAndDebt(
    bytes32 _cType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external isAuthorized {
    SAFEEngineCollateralData storage __cData = _cData[_cType];

    _modifyCollateralBalance(_cType, _collateralSource, -_deltaCollateral);
    _emitTransferCollateral(_cType, address(0), _safe, _deltaCollateral);
    _modifySAFECollateralization(_cType, _safe, _deltaCollateral, _deltaDebt);
    __cData.debtAmount = __cData.debtAmount.add(_deltaDebt);
    __cData.lockedAmount = __cData.lockedAmount.add(_deltaCollateral);

    int256 _deltaTotalIssuedDebt = __cData.accumulatedRate.mul(_deltaDebt);

    debtBalance[_debtDestination] = debtBalance[_debtDestination].sub(_deltaTotalIssuedDebt);
    globalUnbackedDebt = globalUnbackedDebt.sub(_deltaTotalIssuedDebt);

    emit ConfiscateSAFECollateralAndDebt(
      _cType, _safe, _collateralSource, _debtDestination, _deltaCollateral, _deltaDebt
    );
  }

  // --- Settlement ---

  /// @inheritdoc ISAFEEngine
  function settleDebt(uint256 _rad) external {
    address _account = msg.sender;
    debtBalance[_account] -= _rad;
    _modifyInternalCoins(_account, -_rad.toInt());
    globalUnbackedDebt -= _rad;
    emit SettleDebt(_account, _rad);
  }

  /// @inheritdoc ISAFEEngine
  function createUnbackedDebt(address _debtDestination, address _coinDestination, uint256 _rad) external isAuthorized {
    debtBalance[_debtDestination] += _rad;
    _modifyInternalCoins(_coinDestination, _rad.toInt());
    globalUnbackedDebt += _rad;
    emit CreateUnbackedDebt(_debtDestination, _coinDestination, _rad);
  }

  // --- Update ---

  /// @inheritdoc ISAFEEngine
  function updateAccumulatedRate(
    bytes32 _cType,
    address _surplusDst,
    int256 _rateMultiplier
  ) external isAuthorized whenEnabled {
    SAFEEngineCollateralData storage __cData = _cData[_cType];
    __cData.accumulatedRate = __cData.accumulatedRate.add(_rateMultiplier);
    int256 _deltaSurplus = __cData.debtAmount.mul(_rateMultiplier);
    _modifyInternalCoins(_surplusDst, _deltaSurplus);

    emit UpdateAccumulatedRate(_cType, _surplusDst, _rateMultiplier);
  }

  /// @inheritdoc ISAFEEngine
  function updateCollateralPrice(
    bytes32 _cType,
    uint256 _safetyPrice,
    uint256 _liquidationPrice
  ) external isAuthorized whenEnabled {
    _cData[_cType].safetyPrice = _safetyPrice;
    _cData[_cType].liquidationPrice = _liquidationPrice;
    emit UpdateCollateralPrice(_cType, _safetyPrice, _liquidationPrice);
  }

  // --- Authorization ---

  /**
   * @notice Add auth to an account
   * @param  _account Account to add auth to
   */

  /**
   * @dev    This overriden method avoids adding new authorizations after the contract has been disabled
   * @inheritdoc IAuthorizable
   */
  function addAuthorization(address _account) external override(Authorizable, IAuthorizable) isAuthorized whenEnabled {
    _addAuthorization(_account);
  }

  /**
   * @notice Remove auth from an account
   * @param  _account Account to remove auth from
   */
  function removeAuthorization(address _account)
    external
    override(Authorizable, IAuthorizable)
    isAuthorized
    whenEnabled
  {
    _removeAuthorization(_account);
  }

  /// @inheritdoc ISAFEEngine
  function approveSAFEModification(address _account) external {
    safeRights[msg.sender][_account] = true;
    emit ApproveSAFEModification(msg.sender, _account);
  }

  /// @inheritdoc ISAFEEngine
  function denySAFEModification(address _account) external {
    safeRights[msg.sender][_account] = false;
    emit DenySAFEModification(msg.sender, _account);
  }

  /// @inheritdoc ISAFEEngine
  function canModifySAFE(address _safe, address _account) public view returns (bool _canModifySafe) {
    return _safe == _account || safeRights[_safe][_account];
  }

  // --- Internals ---

  function _modifyCollateralBalance(bytes32 _cType, address _account, int256 _wad) internal {
    tokenCollateral[_cType][_account] = tokenCollateral[_cType][_account].add(_wad);
    _emitTransferCollateral(_cType, address(0), _account, _wad);
  }

  function _modifyInternalCoins(address _dst, int256 _rad) internal {
    coinBalance[_dst] = coinBalance[_dst].add(_rad);
    globalDebt = globalDebt.add(_rad);
    if (_rad > 0) emit TransferInternalCoins(address(0), _dst, uint256(_rad));
    else emit TransferInternalCoins(_dst, address(0), uint256(-_rad));
  }

  function _modifySAFECollateralization(
    bytes32 _cType,
    address _safe,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) internal {
    SAFE storage _safeData = _safes[_cType][_safe];
    _safeData.lockedCollateral = _safeData.lockedCollateral.add(_deltaCollateral);
    _safeData.generatedDebt = _safeData.generatedDebt.add(_deltaDebt);

    _emitTransferCollateral(_cType, _safe, address(this), _deltaCollateral);
  }

  function _emitTransferCollateral(bytes32 _cType, address _src, address _dst, int256 _deltaCollateral) internal {
    if (_deltaCollateral == 0) return;
    if (_deltaCollateral >= 0) {
      emit TransferCollateral(_cType, _src, _dst, uint256(_deltaCollateral));
    } else {
      emit TransferCollateral(_cType, _dst, _src, uint256(-_deltaCollateral));
    }
  }

  // --- Administration ---

  /// @inheritdoc ModifiablePerCollateral
  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralParams) internal override whenEnabled {
    (SAFEEngineCollateralParams memory _safeEngineCParams) = abi.decode(_collateralParams, (SAFEEngineCollateralParams));
    _cData[_cType].accumulatedRate = RAY;
    _cParams[_cType] = _safeEngineCParams;
  }

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'globalDebtCeiling') _params.globalDebtCeiling = _uint256;
    else if (_param == 'safeDebtCeiling') _params.safeDebtCeiling = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    if (_param == 'debtCeiling') _cParams[_cType].debtCeiling = _uint256;
    else if (_param == 'debtFloor') _cParams[_cType].debtFloor = _uint256;
    else revert UnrecognizedParam();
  }

  // --- Modifiers ---

  modifier isSAFEAllowed(address _safe, address _account) {
    if (!canModifySAFE(_safe, _account)) revert SAFEEng_NotSAFEAllowed();
    _;
  }
}
