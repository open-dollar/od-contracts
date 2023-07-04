// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/*

Coded for Reflexer and The Money God with ♥ by

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
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY} from '@libraries/Math.sol';

contract SAFEEngine is Authorizable, Modifiable, Disableable, ISAFEEngine {
  using Math for uint256;
  using Encoding for bytes;

  // --- Data ---

  // Data about system parameters
  SAFEEngineParams internal _params;
  // Data about each collateral type parameters
  mapping(bytes32 _cType => SAFEEngineCollateralParams) internal _cParams;
  // Data about each collateral type
  mapping(bytes32 _cType => SAFEEngineCollateralData) internal _cData;
  // Data about each SAFE
  mapping(bytes32 _cType => mapping(address _safe => SAFE)) internal _safes;
  // Who can transfer collateral & debt in/out of a SAFE
  mapping(address _cType => mapping(address _safe => uint256 _isAllowed)) public safeRights;

  function params() external view returns (SAFEEngineParams memory _safeEngineParams) {
    return _params;
  }

  function cParams(bytes32 _cType) external view returns (SAFEEngineCollateralParams memory _safeEngineCParams) {
    return _cParams[_cType];
  }

  function cData(bytes32 _cType) external view returns (SAFEEngineCollateralData memory _collateralData) {
    return _cData[_cType];
  }

  function safes(bytes32 _cType, address _safe) external view returns (SAFE memory _safeData) {
    return _safes[_cType][_safe];
  }

  // --- Balances ---

  // Balance of each collateral type
  mapping(bytes32 _cType => mapping(address _safe => uint256)) public tokenCollateral; // [wad]
  // Internal balance of system coins
  mapping(address _safe => uint256) public coinBalance; // [rad]
  // Amount of debt held by an account. Coins & debt are like matter and antimatter. They nullify each other
  mapping(address _safe => uint256) public debtBalance; // [rad]
  // Total amount of debt (coins) currently issued
  uint256 public globalDebt; // [rad]
  // 'Bad' debt that's not covered by collateral
  uint256 public globalUnbackedDebt; // [rad]

  // --- Init ---
  constructor(SAFEEngineParams memory _safeEngineParams) Authorizable(msg.sender) validParams {
    _params = _safeEngineParams;
    // TODO: add ModifyParameters events here
  }

  function initializeCollateralType(
    bytes32 _cType,
    SAFEEngineCollateralParams memory _collateralParams
  ) external isAuthorized {
    if (_cData[_cType].accumulatedRate != 0) revert SAFEEng_CollateralTypeAlreadyExists();
    _cData[_cType].accumulatedRate = RAY;
    _cParams[_cType] = _collateralParams;
    emit InitializeCollateralType(_cType);
    // TODO: add ModifyParameters events here
  }

  // --- Fungibility ---

  /**
   * @notice Transfer collateral between accounts
   * @param _cType Collateral type transferred
   * @param _source Collateral source
   * @param _destination Collateral destination
   * @param _wad Amount of collateral transferred
   */
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

  /**
   * @notice Transfer internal coins (does not affect external balances from Coin.sol)
   * @param  _source Coins source
   * @param  _destination Coins destination
   * @param  _rad Amount of coins transferred
   */
  function transferInternalCoins(
    address _source,
    address _destination,
    uint256 _rad
  ) external isSAFEAllowed(_source, msg.sender) {
    coinBalance[_source] -= _rad;
    coinBalance[_destination] += _rad;
    emit TransferInternalCoins(_source, _destination, _rad);
  }

  /**
   * @notice Join/exit collateral into and and out of the system
   * @param _cType Collateral type to join/exit
   * @param _account Account that gets credited/debited
   * @param _wad Amount of collateral
   */
  function modifyCollateralBalance(bytes32 _cType, address _account, int256 _wad) external isAuthorized {
    _modifyCollateralBalance(_cType, _account, _wad);
  }

  // --- SAFE Manipulation ---
  /**
   * @notice Add/remove collateral or put back/generate more debt in a SAFE
   * @param _cType Type of collateral to withdraw/deposit in and from the SAFE
   * @param _safe Target SAFE
   * @param _collateralSource Account we take collateral from/put collateral into
   * @param _debtDestination Account from which we credit/debit coins and debt
   * @param _deltaCollateral Amount of collateral added/extract from the SAFE (wad)
   * @param _deltaDebt Amount of debt to generate/repay (wad)
   */
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
  /**
   * @notice Transfer collateral and/or debt between SAFEs
   * @param _cType Collateral type transferred between SAFEs
   * @param _src Source SAFE
   * @param _dst Destination SAFE
   * @param _deltaCollateral Amount of collateral to take/add into src and give/take from dst (wad)
   * @param _deltaDebt Amount of debt to take/add into src and give/take from dst (wad)
   */
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
  /**
   * @notice Normally used by the LiquidationEngine in order to confiscate collateral and
   *      debt from a SAFE and give them to someone else
   * @param _cType Collateral type the SAFE has locked inside
   * @param _safe Target SAFE
   * @param _collateralSource Who we take/give collateral to
   * @param _debtDestination Who we take/give debt to
   * @param _deltaCollateral Amount of collateral taken/added into the SAFE (wad)
   * @param _deltaDebt Amount of debt taken/added into the SAFE (wad)
   */
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

    int256 _deltaTotalIssuedDebt = __cData.accumulatedRate.mul(_deltaDebt);

    debtBalance[_debtDestination] = debtBalance[_debtDestination].sub(_deltaTotalIssuedDebt);
    globalUnbackedDebt = globalUnbackedDebt.sub(_deltaTotalIssuedDebt);

    emit ConfiscateSAFECollateralAndDebt(
      _cType, _safe, _collateralSource, _debtDestination, _deltaCollateral, _deltaDebt
    );
  }

  // --- Settlement ---
  /**
   * @notice Nullify an amount of coins with an equal amount of debt
   * @param  _rad Amount of debt & coins to destroy
   */
  function settleDebt(uint256 _rad) external {
    address _account = msg.sender;
    debtBalance[_account] -= _rad;
    _modifyInternalCoins(_account, -_rad.toInt());
    globalUnbackedDebt -= _rad;
    emit SettleDebt(_account, _rad);
  }

  /**
   * @notice Allows an authorized contract to create debt without collateral
   * @param _debtDestination The account that will receive the newly created debt
   * @param _coinDestination The account that will receive the newly created coins
   * @param _rad Amount of debt to create
   * @dev   Usually called by DebtAuctionHouse in order to terminate auctions prematurely post settlement
   */
  function createUnbackedDebt(address _debtDestination, address _coinDestination, uint256 _rad) external isAuthorized {
    debtBalance[_debtDestination] += _rad;
    _modifyInternalCoins(_coinDestination, _rad.toInt());
    globalUnbackedDebt += _rad;
    emit CreateUnbackedDebt(_debtDestination, _coinDestination, _rad);
  }

  // --- Update ---
  /**
   * @notice Allows an authorized contract to accrue interest on a specific collateral type
   * @param _cType Collateral type we accrue interest for
   * @param _surplusDst Destination for the newly created surplus
   * @param _rateMultiplier Multiplier applied to the debtAmount in order to calculate the surplus [ray]
   * @dev   The rateMultiplier is usually calculated by the TaxCollector contract
   */
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
   * @param _account Account to add auth to
   */
  function addAuthorization(address _account) external override(Authorizable, IAuthorizable) isAuthorized whenEnabled {
    _addAuthorization(_account);
  }

  /**
   * @notice Remove auth from an account
   * @param _account Account to remove auth from
   */
  function removeAuthorization(address _account)
    external
    override(Authorizable, IAuthorizable)
    isAuthorized
    whenEnabled
  {
    _removeAuthorization(_account);
  }

  /**
   * @notice Allow an address to modify your SAFE
   * @param _account Account to give SAFE permissions to
   */
  function approveSAFEModification(address _account) external {
    safeRights[msg.sender][_account] = 1;
    emit ApproveSAFEModification(msg.sender, _account);
  }

  /**
   * @notice Deny an address the rights to modify your SAFE
   * @param _account Account that is denied SAFE permissions
   */
  function denySAFEModification(address _account) external {
    safeRights[msg.sender][_account] = 0;
    emit DenySAFEModification(msg.sender, _account);
  }

  /**
   * @notice Checks whether msg.sender has the right to modify a SAFE
   */
  function canModifySAFE(address _safe, address _account) public view returns (bool _canModifySafe) {
    return _safe == _account || safeRights[_safe][_account] == 1;
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
    if(_deltaCollateral == 0) return;
    if (_deltaCollateral >= 0) {
      emit TransferCollateral(_cType, _src, _dst, uint256(_deltaCollateral));
    } else {
      emit TransferCollateral(_cType, _dst, _src, uint256(-_deltaCollateral));
    }
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override whenEnabled {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'globalDebtCeiling') _params.globalDebtCeiling = _uint256;
    else if (_param == 'safeDebtCeiling') _params.safeDebtCeiling = _uint256;
    else revert UnrecognizedParam();
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override whenEnabled {
    uint256 _uint256 = _data.toUint256();

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
