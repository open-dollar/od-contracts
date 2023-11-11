// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ISAFESaviour} from '@interfaces/external/ISAFESaviour.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {IModifiablePerCollateral, ModifiablePerCollateral} from '@contracts/utils/ModifiablePerCollateral.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Math, RAY, WAD, MAX_RAD} from '@libraries/Math.sol';

/**
 * @title  LiquidationEngine
 * @notice Handles the liquidations of SAFEs if the accumulated debt is higher than the collateral liquidation value
 */
contract LiquidationEngine is
  Authorizable,
  Disableable,
  Modifiable,
  ModifiablePerCollateral,
  ReentrancyGuard,
  ILiquidationEngine
{
  using Math for uint256;
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- SAFE Saviours ---

  /// @inheritdoc ILiquidationEngine
  mapping(address _saviour => bool _allowed) public safeSaviours;

  /// @inheritdoc ILiquidationEngine
  mapping(bytes32 _cType => mapping(address _safe => address _saviour)) public chosenSAFESaviour;

  // --- Data ---

  /// @inheritdoc ILiquidationEngine
  uint256 public /* RAD */ currentOnAuctionSystemCoins;

  // --- Registry ---

  /// @inheritdoc ILiquidationEngine
  ISAFEEngine public safeEngine;
  /// @inheritdoc ILiquidationEngine
  IAccountingEngine public accountingEngine;

  // --- Params ---

  /// @inheritdoc ILiquidationEngine
  // solhint-disable-next-line private-vars-leading-underscore
  LiquidationEngineParams public _params;
  /// @inheritdoc ILiquidationEngine
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(bytes32 _cType => LiquidationEngineCollateralParams) public _cParams;

  /// @inheritdoc ILiquidationEngine
  function params() external view returns (LiquidationEngineParams memory _liqEngineParams) {
    return _params;
  }

  /// @inheritdoc ILiquidationEngine
  function cParams(bytes32 _cType) external view returns (LiquidationEngineCollateralParams memory _liqEngineCParams) {
    return _cParams[_cType];
  }

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _accountingEngine Address of the AccountingEngine contract
   * @param  _liqEngineParams Initial valid LiquidationEngine parameters struct
   */
  constructor(
    address _safeEngine,
    address _accountingEngine,
    LiquidationEngineParams memory _liqEngineParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    accountingEngine = IAccountingEngine(_accountingEngine);

    _params = _liqEngineParams;
  }

  /// @inheritdoc ILiquidationEngine
  function connectSAFESaviour(address _saviour) external isAuthorized {
    (bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward) =
      ISAFESaviour(_saviour).saveSAFE(address(this), '', address(0));
    if (!_ok) revert LiqEng_SaviourNotOk();
    if (_collateralAdded != type(uint256).max || _liquidatorReward != type(uint256).max) revert LiqEng_InvalidAmounts();
    safeSaviours[_saviour] = true;
    emit ConnectSAFESaviour(_saviour);
  }

  /// @inheritdoc ILiquidationEngine
  function disconnectSAFESaviour(address _saviour) external isAuthorized {
    safeSaviours[_saviour] = false;
    emit DisconnectSAFESaviour(_saviour);
  }

  // --- SAFE Liquidation ---

  /// @inheritdoc ILiquidationEngine
  function protectSAFE(bytes32 _cType, address _safe, address _saviour) external {
    if (!safeEngine.canModifySAFE(_safe, msg.sender)) revert LiqEng_CannotModifySAFE();
    if (_saviour != address(0) && !safeSaviours[_saviour]) revert LiqEng_SaviourNotAuthorized();

    chosenSAFESaviour[_cType][_safe] = _saviour;
    emit ProtectSAFE(_cType, _safe, _saviour);
  }

  /// @inheritdoc ILiquidationEngine
  function liquidateSAFE(bytes32 _cType, address _safe) external whenEnabled nonReentrant returns (uint256 _auctionId) {
    uint256 _debtFloor = safeEngine.cParams(_cType).debtFloor;
    ISAFEEngine.SAFEEngineCollateralData memory _safeEngCData = safeEngine.cData(_cType);
    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(_cType, _safe);

    // --- Safety checks ---
    {
      if (
        _safeEngCData.liquidationPrice == 0
          || _safeData.lockedCollateral * _safeEngCData.liquidationPrice
            >= _safeData.generatedDebt * _safeEngCData.accumulatedRate
      ) revert LiqEng_SAFENotUnsafe();
    }

    // If an approved saviour is set for this safe we give it a chance to safe the save.
    if (chosenSAFESaviour[_cType][_safe] != address(0) && safeSaviours[chosenSAFESaviour[_cType][_safe]]) {
      try this.attemptSave{gas: _params.saviourGasLimit}(_cType, _safe, msg.sender, _safeData) returns (
        ISAFEEngine.SAFE memory _newSafeData
      ) {
        _safeEngCData = safeEngine.cData(_cType);
        _safeData = _newSafeData;
      } catch (bytes memory _revertReason) {
        emit FailedSAFESave(_revertReason);
      }
    }

    if (
      _safeData.lockedCollateral * _safeEngCData.liquidationPrice
        < _safeData.generatedDebt * _safeEngCData.accumulatedRate
    ) {
      LiquidationEngineCollateralParams memory __cParams = _cParams[_cType];

      uint256 _limitAdjustedDebt = _getLimitAdjustedDebt(
        _safeData.generatedDebt,
        _safeEngCData.accumulatedRate,
        __cParams.liquidationQuantity,
        __cParams.liquidationPenalty,
        _debtFloor
      );

      uint256 _collateralToSell = _safeData.lockedCollateral * _limitAdjustedDebt / _safeData.generatedDebt;
      uint256 _amountToRaise = (_limitAdjustedDebt * _safeEngCData.accumulatedRate).wmul(__cParams.liquidationPenalty);

      // --- Safety checks ---
      {
        if (_limitAdjustedDebt == 0) revert LiqEng_NullAuction();

        if (_collateralToSell == 0) revert LiqEng_NullCollateralToSell();

        if (currentOnAuctionSystemCoins + _amountToRaise > _params.onAuctionSystemCoinLimit) {
          revert LiqEng_LiquidationLimitHit();
        }
      }

      safeEngine.confiscateSAFECollateralAndDebt({
        _cType: _cType,
        _safe: _safe,
        _collateralSource: address(this),
        _debtDestination: address(accountingEngine),
        _deltaCollateral: -_collateralToSell.toInt(),
        _deltaDebt: -_limitAdjustedDebt.toInt()
      });

      accountingEngine.pushDebtToQueue(_limitAdjustedDebt * _safeEngCData.accumulatedRate);

      currentOnAuctionSystemCoins += _amountToRaise;

      _auctionId = ICollateralAuctionHouse(__cParams.collateralAuctionHouse).startAuction({
        _forgoneCollateralReceiver: _safe,
        _auctionIncomeRecipient: address(accountingEngine),
        _amountToRaise: _amountToRaise,
        _collateralToSell: _collateralToSell
      });

      emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);

      emit Liquidate({
        _cType: _cType,
        _safe: _safe,
        _collateralAmount: _collateralToSell,
        _debtAmount: _limitAdjustedDebt,
        _amountToRaise: _amountToRaise,
        _collateralAuctioneer: __cParams.collateralAuctionHouse,
        _auctionId: _auctionId
      });
    }
  }

  function attemptSave(
    bytes32 _cType,
    address _safe,
    address _liquidator,
    ISAFEEngine.SAFE calldata _safeData
  ) external returns (ISAFEEngine.SAFE memory _newSafeData) {
    if (msg.sender != address(this)) revert LiqEng_OnlyLiqEng();

    // Call the saviour and attempt to save the safe
    (bool _ok, uint256 _collateralAddedOrDebtRepaid,) =
      ISAFESaviour(chosenSAFESaviour[_cType][_safe]).saveSAFE(_liquidator, _cType, _safe);
    if (_ok && _collateralAddedOrDebtRepaid > 0) {
      // Checks that the saviour didn't take collateral or add more debt to the SAFE
      _newSafeData = safeEngine.safes(_cType, _safe);

      // --- Safety checks ---
      {
        if (
          _newSafeData.lockedCollateral < _safeData.lockedCollateral
            || _newSafeData.generatedDebt > _safeData.generatedDebt
        ) revert LiqEng_InvalidSAFESaviourOperation();
      }

      emit SaveSAFE(_cType, _safe, _collateralAddedOrDebtRepaid);
      return _newSafeData;
    }

    _newSafeData = _safeData;
  }

  /// @inheritdoc ILiquidationEngine
  function removeCoinsFromAuction(uint256 _rad) public isAuthorized {
    currentOnAuctionSystemCoins -= _rad;
    emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);
  }

  // --- Getters ---

  /// @inheritdoc ILiquidationEngine
  function getLimitAdjustedDebtToCover(
    bytes32 _cType,
    address _safe
  ) external view returns (uint256 _limitAdjustedDebtToCover) {
    uint256 _debtFloor = safeEngine.cParams(_cType).debtFloor;
    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    uint256 _generatedDebt = safeEngine.safes(_cType, _safe).generatedDebt;
    LiquidationEngineCollateralParams memory __cParams = _cParams[_cType];

    return _getLimitAdjustedDebt(
      _generatedDebt, _accumulatedRate, __cParams.liquidationQuantity, __cParams.liquidationPenalty, _debtFloor
    );
  }

  function _getLimitAdjustedDebt(
    uint256 _generatedDebt,
    uint256 _accumulatedRate,
    uint256 _liquidationQuantity,
    uint256 _liquidationPenalty,
    uint256 _debtFloor
  ) internal pure returns (uint256 _limitAdjustedDebt) {
    _limitAdjustedDebt = Math.min(_generatedDebt, _liquidationQuantity.wdiv(_liquidationPenalty) / _accumulatedRate);

    // NOTE: If the SAFE is dusty afterwards, we liquidate the whole debt
    _limitAdjustedDebt = _limitAdjustedDebt != _generatedDebt
      && _generatedDebt - _limitAdjustedDebt < _debtFloor / _accumulatedRate ? _generatedDebt : _limitAdjustedDebt;

    return _limitAdjustedDebt;
  }

  // --- Administration ---

  /// @inheritdoc ModifiablePerCollateral
  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralParams) internal override whenEnabled {
    (LiquidationEngineCollateralParams memory _liqEngineCParams) =
      abi.decode(_collateralParams, (LiquidationEngineCollateralParams));
    _setCollateralAuctionHouse(_cType, _liqEngineCParams.collateralAuctionHouse);
    _cParams[_cType] = _liqEngineCParams;
  }

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    if (_param == 'onAuctionSystemCoinLimit') _params.onAuctionSystemCoinLimit = _data.toUint256();
    else if (_param == 'accountingEngine') accountingEngine = IAccountingEngine(_data.toAddress());
    else if (_param == 'saviourGasLimit') _params.saviourGasLimit = _data.toUint256();
    else revert UnrecognizedParam();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    if (_param == 'liquidationPenalty') _cParams[_cType].liquidationPenalty = _uint256;
    else if (_param == 'liquidationQuantity') _cParams[_cType].liquidationQuantity = _uint256;
    else if (_param == 'collateralAuctionHouse') _setCollateralAuctionHouse(_cType, _data.toAddress());
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(accountingEngine).assertHasCode();
  }

  /// @inheritdoc ModifiablePerCollateral
  function _validateCParameters(bytes32 _cType) internal view override {
    LiquidationEngineCollateralParams memory __cParams = _cParams[_cType];
    address(__cParams.collateralAuctionHouse).assertHasCode();
    __cParams.liquidationQuantity.assertLtEq(MAX_RAD);
  }

  /// @dev Set the collateral auction house, deny permissions on the old one and approve on the new one
  function _setCollateralAuctionHouse(bytes32 _cType, address _newCollateralAuctionHouse) internal {
    LiquidationEngineCollateralParams storage __cParams = _cParams[_cType];
    if (__cParams.collateralAuctionHouse != address(0)) {
      safeEngine.denySAFEModification(__cParams.collateralAuctionHouse);
      _removeAuthorization(__cParams.collateralAuctionHouse);
    }
    __cParams.collateralAuctionHouse = _newCollateralAuctionHouse;
    safeEngine.approveSAFEModification(_newCollateralAuctionHouse);
    _addAuthorization(_newCollateralAuctionHouse);
  }
}
