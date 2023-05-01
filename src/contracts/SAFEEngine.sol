// SPDX-License-Identifier: GPL-3.0
/// SAFEEngine.sol -- SAFE database

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {ISAFEEngine, GLOBAL_PARAM} from '@interfaces/ISAFEEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Math, RAY} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Authorizable} from '@contract-utils/Authorizable.sol';
import {Disableable} from '@contract-utils/Disableable.sol';

contract SAFEEngine is Authorizable, Disableable, ISAFEEngine {
  using Math for uint256;
  using Encoding for bytes;

  // --- Auth ---
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

  // Who can transfer collateral & debt in/out of a SAFE
  mapping(address => mapping(address => uint256)) public safeRights;

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

  SAFEEngineParams public params;
  // Data about each collateral type
  mapping(bytes32 _cType => SAFEEngineCollateralParams) public cParams;
  // Data about each collateral type
  mapping(bytes32 _cType => SAFEEngineCollateralData) public cData;
  // Data about each SAFE
  mapping(bytes32 _cType => mapping(address _safe => SAFE)) public safes;
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
  constructor() Authorizable(msg.sender) {
    params.safeDebtCeiling = type(uint256).max;
    emit ModifyParameters('safeDebtCeiling', GLOBAL_PARAM, abi.encode(type(uint256).max));
  }

  // --- Administration ---
  /**
   * @notice Creates a brand new collateral type
   * @param _cType Collateral type name (e.g ETH-A, TBTC-B)
   */
  function initializeCollateralType(bytes32 _cType) external isAuthorized {
    require(cData[_cType].accumulatedRate == 0, 'SAFEEngine/collateral-type-already-exists');
    cData[_cType].accumulatedRate = RAY;
    emit InitializeCollateralType(_cType);
  }

  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */
  function disableContract() external isAuthorized {
    _disableContract();
  }

  // --- Fungibility ---
  /**
   * @notice Join/exit collateral into and and out of the system
   * @param _cType Collateral type to join/exit
   * @param _account Account that gets credited/debited
   * @param _wad Amount of collateral
   */
  function modifyCollateralBalance(bytes32 _cType, address _account, int256 _wad) external isAuthorized {
    tokenCollateral[_cType][_account] = tokenCollateral[_cType][_account].add(_wad);
    emit ModifyCollateralBalance(_cType, _account, _wad);
  }

  /**
   * @notice Transfer collateral between accounts
   * @param _cType Collateral type transferred
   * @param _src Collateral source
   * @param _dst Collateral destination
   * @param _wad Amount of collateral transferred
   */
  function transferCollateral(
    bytes32 _cType,
    address _src,
    address _dst,
    uint256 _wad
  ) external isSAFEAllowed(_src, msg.sender) {
    tokenCollateral[_cType][_src] -= _wad;
    tokenCollateral[_cType][_dst] += _wad;
    emit TransferCollateral(_cType, _src, _dst, _wad);
  }

  /**
   * @notice Transfer internal coins (does not affect external balances from Coin.sol)
   * @param  _src Coins source
   * @param  _dst Coins destination
   * @param  _rad Amount of coins transferred
   */
  function transferInternalCoins(address _src, address _dst, uint256 _rad) external isSAFEAllowed(_src, msg.sender) {
    coinBalance[_src] -= _rad;
    coinBalance[_dst] += _rad;
    emit TransferInternalCoins(_src, _dst, _rad);
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
    SAFE storage safeData_ = safes[_cType][_safe];
    SAFEEngineCollateralData storage cData_ = cData[_cType];
    SAFEEngineCollateralParams memory _cParams = cParams[_cType];
    // collateral type has been initialised
    require(cData_.accumulatedRate != 0, 'SAFEEngine/collateral-type-not-initialized');

    safeData_.lockedCollateral = safeData_.lockedCollateral.add(_deltaCollateral);
    safeData_.generatedDebt = safeData_.generatedDebt.add(_deltaDebt);
    cData_.debtAmount = cData_.debtAmount.add(_deltaDebt);

    int256 _deltaAdjustedDebt = cData_.accumulatedRate.mul(_deltaDebt);
    uint256 _totalDebtIssued = cData_.accumulatedRate * safeData_.generatedDebt;
    globalDebt = globalDebt.add(_deltaAdjustedDebt);

    // either debt has decreased, or debt ceilings are not exceeded
    require(
      _deltaDebt <= 0
        || (cData_.debtAmount * cData_.accumulatedRate <= _cParams.debtCeiling && globalDebt <= params.globalDebtCeiling),
      'SAFEEngine/ceiling-exceeded'
    );
    // safe is either less risky than before, or it is safe
    require(
      (_deltaDebt <= 0 && _deltaCollateral >= 0)
        || _totalDebtIssued <= safeData_.lockedCollateral * _cParams.safetyPrice,
      'SAFEEngine/not-safe'
    );

    // safe is either more safe, or the owner consents
    require(
      (_deltaDebt <= 0 && _deltaCollateral >= 0) || canModifySAFE(_safe, msg.sender),
      'SAFEEngine/not-allowed-to-modify-safe'
    );
    // collateral src consents
    require(
      _deltaCollateral <= 0 || canModifySAFE(_collateralSource, msg.sender), 'SAFEEngine/not-allowed-collateral-src'
    );
    // debt dst consents
    require(_deltaDebt >= 0 || canModifySAFE(_debtDestination, msg.sender), 'SAFEEngine/not-allowed-debt-dst');

    // safe has no debt, or a non-dusty amount
    require(safeData_.generatedDebt == 0 || _totalDebtIssued >= _cParams.debtFloor, 'SAFEEngine/dust');

    // safe didn't go above the safe debt limit
    if (_deltaDebt > 0) {
      require(safeData_.generatedDebt <= params.safeDebtCeiling, 'SAFEEngine/above-debt-limit');
    }

    tokenCollateral[_cType][_collateralSource] = tokenCollateral[_cType][_collateralSource].sub(_deltaCollateral);

    coinBalance[_debtDestination] = coinBalance[_debtDestination].add(_deltaAdjustedDebt);

    emit ModifySAFECollateralization(
      _cType,
      _safe,
      _collateralSource,
      _debtDestination,
      _deltaCollateral,
      _deltaDebt,
      safeData_.lockedCollateral,
      safeData_.generatedDebt,
      globalDebt
    );
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
    SAFE storage srcSAFE_ = safes[_cType][_src];
    SAFE storage dstSAFE_ = safes[_cType][_dst];
    SAFEEngineCollateralParams memory _cParams = cParams[_cType];
    SAFEEngineCollateralData memory _cData = cData[_cType];

    {
      srcSAFE_.lockedCollateral = srcSAFE_.lockedCollateral.sub(_deltaCollateral);
      srcSAFE_.generatedDebt = srcSAFE_.generatedDebt.sub(_deltaDebt);
      dstSAFE_.lockedCollateral = dstSAFE_.lockedCollateral.add(_deltaCollateral);
      dstSAFE_.generatedDebt = dstSAFE_.generatedDebt.add(_deltaDebt);

      uint256 _srcTotalDebtIssued = srcSAFE_.generatedDebt * _cData.accumulatedRate;
      uint256 _dstTotalDebtIssued = dstSAFE_.generatedDebt * _cData.accumulatedRate;

      // both sides safe
      require(_srcTotalDebtIssued <= srcSAFE_.lockedCollateral * _cParams.safetyPrice, 'SAFEEngine/not-safe-src');
      require(_dstTotalDebtIssued <= dstSAFE_.lockedCollateral * _cParams.safetyPrice, 'SAFEEngine/not-safe-dst');

      // both sides non-dusty
      require(_srcTotalDebtIssued >= _cParams.debtFloor || srcSAFE_.generatedDebt == 0, 'SAFEEngine/dust-src');
      require(_dstTotalDebtIssued >= _cParams.debtFloor || dstSAFE_.generatedDebt == 0, 'SAFEEngine/dust-dst');
    }

    emit TransferSAFECollateralAndDebt(
      _cType,
      _src,
      _dst,
      _deltaCollateral,
      _deltaDebt,
      srcSAFE_.lockedCollateral,
      srcSAFE_.generatedDebt,
      dstSAFE_.lockedCollateral,
      dstSAFE_.generatedDebt
    );
  }

  // --- SAFE Confiscation ---
  /**
   * @notice Normally used by the LiquidationEngine in order to confiscate collateral and
   *      debt from a SAFE and give them to someone else
   * @param _cType Collateral type the SAFE has locked inside
   * @param _safe Target SAFE
   * @param _collateralCounterparty Who we take/give collateral to
   * @param _debtCounterparty Who we take/give debt to
   * @param _deltaCollateral Amount of collateral taken/added into the SAFE (wad)
   * @param _deltaDebt Amount of debt taken/added into the SAFE (wad)
   */
  function confiscateSAFECollateralAndDebt(
    bytes32 _cType,
    address _safe,
    address _collateralCounterparty,
    address _debtCounterparty,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external isAuthorized {
    SAFE storage safe_ = safes[_cType][_safe];
    SAFEEngineCollateralData storage cData_ = cData[_cType];

    safe_.lockedCollateral = safe_.lockedCollateral.add(_deltaCollateral);
    safe_.generatedDebt = safe_.generatedDebt.add(_deltaDebt);
    cData_.debtAmount = cData_.debtAmount.add(_deltaDebt);

    int256 deltaTotalIssuedDebt = cData_.accumulatedRate.mul(_deltaDebt);

    tokenCollateral[_cType][_collateralCounterparty] =
      tokenCollateral[_cType][_collateralCounterparty].sub(_deltaCollateral);
    debtBalance[_debtCounterparty] = debtBalance[_debtCounterparty].sub(deltaTotalIssuedDebt);
    globalUnbackedDebt = globalUnbackedDebt.sub(deltaTotalIssuedDebt);

    emit ConfiscateSAFECollateralAndDebt(
      _cType, _safe, _collateralCounterparty, _debtCounterparty, _deltaCollateral, _deltaDebt, globalUnbackedDebt
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
    coinBalance[_account] -= _rad;
    globalUnbackedDebt -= _rad;
    globalDebt -= _rad;
    emit SettleDebt(_account, _rad, debtBalance[_account], coinBalance[_account], globalUnbackedDebt, globalDebt);
  }

  /**
   * @notice Usually called by CoinSavingsAccount in order to create unbacked debt
   * @param _debtDestination Usually AccountingEngine that can settle uncovered debt with surplus
   * @param _coinDestination Usually CoinSavingsAccount that passes the new coins to depositors
   * @param _rad Amount of debt to create
   */
  function createUnbackedDebt(address _debtDestination, address _coinDestination, uint256 _rad) external isAuthorized {
    debtBalance[_debtDestination] += _rad;
    coinBalance[_coinDestination] += _rad;
    globalUnbackedDebt += _rad;
    globalDebt += _rad;
    emit CreateUnbackedDebt(
      _debtDestination,
      _coinDestination,
      _rad,
      debtBalance[_debtDestination],
      coinBalance[_coinDestination],
      globalUnbackedDebt,
      globalDebt
    );
  }

  // --- Rates ---
  /**
   * @notice Usually called by TaxCollector in order to accrue interest on a specific collateral type
   * @param _cType Collateral type we accrue interest for
   * @param _surplusDst Destination for the newly created surplus
   * @param _rateMultiplier Multiplier applied to the debtAmount in order to calculate the surplus [ray]
   */
  function updateAccumulatedRate(
    bytes32 _cType,
    address _surplusDst,
    int256 _rateMultiplier
  ) external isAuthorized whenEnabled {
    SAFEEngineCollateralData storage cData_ = cData[_cType];
    cData_.accumulatedRate = cData_.accumulatedRate.add(_rateMultiplier);
    int256 _deltaSurplus = cData_.debtAmount.mul(_rateMultiplier);
    coinBalance[_surplusDst] = coinBalance[_surplusDst].add(_deltaSurplus);
    globalDebt = globalDebt.add(_deltaSurplus);
    emit UpdateAccumulatedRate(_cType, _surplusDst, _rateMultiplier, coinBalance[_surplusDst], globalDebt);
  }

  // --- Administration ---
  /**
   * @notice Modify general params
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _parameter, bytes memory _data) external isAuthorized whenEnabled {
    uint256 _uint256 = _data.toUint256();

    if (_parameter == 'globalDebtCeiling') params.globalDebtCeiling = _uint256;
    else if (_parameter == 'safeDebtCeiling') params.safeDebtCeiling = _uint256;
    else revert('SAFEEngine/modify-unrecognized-param');
    emit ModifyParameters(_parameter, GLOBAL_PARAM, _data);
  }

  /**
   * @notice Modify collateral specific params
   * @param _cType Collateral type we modify params for
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _cType, bytes32 _parameter, bytes memory _data) public isAuthorized whenEnabled {
    uint256 _uint256 = _data.toUint256();

    if (_parameter == 'safetyPrice') cParams[_cType].safetyPrice = _uint256;
    else if (_parameter == 'liquidationPrice') cParams[_cType].liquidationPrice = _uint256;
    else if (_parameter == 'debtCeiling') cParams[_cType].debtCeiling = _uint256;
    else if (_parameter == 'debtFloor') cParams[_cType].debtFloor = _uint256;
    else revert('SAFEEngine/modify-unrecognized-param');
    emit ModifyParameters(_cType, _parameter, _data);
  }

  // --- Modifiers ---
  modifier isSAFEAllowed(address _safe, address _account) {
    if (!canModifySAFE(_safe, _account)) revert NotSAFEAllowed();
    _;
  }
}