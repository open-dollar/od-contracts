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

import {IAuthorizable} from '@interfaces/IAuthorizable.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {Math, RAY} from '@libraries/Math.sol';
import {Authorizable} from '@contract-utils/Authorizable.sol';

contract SAFEEngine is Authorizable, ISAFEEngine {
  using Math for uint256;

  // --- Auth ---
  /**
   * @notice Add auth to an account
   * @param _account Account to add auth to
   */
  function addAuthorization(address _account) external override(Authorizable, IAuthorizable) isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    _addAuthorization(_account);
  }

  /**
   * @notice Remove auth from an account
   * @param _account Account to remove auth from
   */
  function removeAuthorization(address _account) external override(Authorizable, IAuthorizable) isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
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

  // Data about each collateral type
  mapping(bytes32 => CollateralType) public collateralTypes;
  // Data about each SAFE
  mapping(bytes32 => mapping(address => SAFE)) public safes;
  // Balance of each collateral type
  mapping(bytes32 => mapping(address => uint256)) public tokenCollateral; // [wad]
  // Internal balance of system coins
  mapping(address => uint256) public coinBalance; // [rad]
  // Amount of debt held by an account. Coins & debt are like matter and antimatter. They nullify each other
  mapping(address => uint256) public debtBalance; // [rad]

  // Total amount of debt that a single safe can generate
  uint256 public safeDebtCeiling; // [wad]
  // Total amount of debt (coins) currently issued
  uint256 public globalDebt; // [rad]
  // 'Bad' debt that's not covered by collateral
  uint256 public globalUnbackedDebt; // [rad]
  // Maximum amount of debt that can be issued
  uint256 public globalDebtCeiling; // [rad]
  // Access flag, indicates whether this contract is still active
  uint256 public contractEnabled;

  // --- Init ---
  constructor() Authorizable(msg.sender) {
    safeDebtCeiling = type(uint256).max;
    contractEnabled = 1;
    emit ModifyParameters('safeDebtCeiling', type(uint256).max);
  }

  // --- Administration ---
  /**
   * @notice Creates a brand new collateral type
   * @param _collateralType Collateral type name (e.g ETH-A, TBTC-B)
   */
  function initializeCollateralType(bytes32 _collateralType) external isAuthorized {
    require(collateralTypes[_collateralType].accumulatedRate == 0, 'SAFEEngine/collateral-type-already-exists');
    collateralTypes[_collateralType].accumulatedRate = RAY;
    emit InitializeCollateralType(_collateralType);
  }

  /**
   * @notice Modify general uint256 params
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _parameter, uint256 _data) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    if (_parameter == 'globalDebtCeiling') globalDebtCeiling = _data;
    else if (_parameter == 'safeDebtCeiling') safeDebtCeiling = _data;
    else revert('SAFEEngine/modify-unrecognized-param');
    emit ModifyParameters(_parameter, _data);
  }

  /**
   * @notice Modify collateral specific params
   * @param _collateralType Collateral type we modify params for
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _collateralType, bytes32 _parameter, uint256 _data) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    if (_parameter == 'safetyPrice') collateralTypes[_collateralType].safetyPrice = _data;
    else if (_parameter == 'liquidationPrice') collateralTypes[_collateralType].liquidationPrice = _data;
    else if (_parameter == 'debtCeiling') collateralTypes[_collateralType].debtCeiling = _data;
    else if (_parameter == 'debtFloor') collateralTypes[_collateralType].debtFloor = _data;
    else revert('SAFEEngine/modify-unrecognized-param');
    emit ModifyParameters(_collateralType, _parameter, _data);
  }

  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */
  function disableContract() external isAuthorized {
    contractEnabled = 0;
    emit DisableContract();
  }

  // --- Fungibility ---
  /**
   * @notice Join/exit collateral into and and out of the system
   * @param _collateralType Collateral type to join/exit
   * @param _account Account that gets credited/debited
   * @param _wad Amount of collateral
   */
  function modifyCollateralBalance(bytes32 _collateralType, address _account, int256 _wad) external isAuthorized {
    tokenCollateral[_collateralType][_account] = tokenCollateral[_collateralType][_account].add(_wad);
    emit ModifyCollateralBalance(_collateralType, _account, _wad);
  }

  /**
   * @notice Transfer collateral between accounts
   * @param _collateralType Collateral type transferred
   * @param _src Collateral source
   * @param _dst Collateral destination
   * @param _wad Amount of collateral transferred
   */
  function transferCollateral(
    bytes32 _collateralType,
    address _src,
    address _dst,
    uint256 _wad
  ) external isSAFEAllowed(_src, msg.sender) {
    tokenCollateral[_collateralType][_src] -= _wad;
    tokenCollateral[_collateralType][_dst] += _wad;
    emit TransferCollateral(_collateralType, _src, _dst, _wad);
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
   * @param _collateralType Type of collateral to withdraw/deposit in and from the SAFE
   * @param _safe Target SAFE
   * @param _collateralSource Account we take collateral from/put collateral into
   * @param _debtDestination Account from which we credit/debit coins and debt
   * @param _deltaCollateral Amount of collateral added/extract from the SAFE (wad)
   * @param _deltaDebt Amount of debt to generate/repay (wad)
   */
  function modifySAFECollateralization(
    bytes32 _collateralType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external {
    // system is live
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');

    SAFE memory safeData = safes[_collateralType][_safe];
    CollateralType memory collateralTypeData = collateralTypes[_collateralType];
    // collateral type has been initialised
    require(collateralTypeData.accumulatedRate != 0, 'SAFEEngine/collateral-type-not-initialized');

    safeData.lockedCollateral = safeData.lockedCollateral.add(_deltaCollateral);
    safeData.generatedDebt = safeData.generatedDebt.add(_deltaDebt);
    collateralTypeData.debtAmount = collateralTypeData.debtAmount.add(_deltaDebt);

    int256 _deltaAdjustedDebt = collateralTypeData.accumulatedRate.mul(_deltaDebt);
    uint256 _totalDebtIssued = collateralTypeData.accumulatedRate * safeData.generatedDebt;
    globalDebt = globalDebt.add(_deltaAdjustedDebt);

    // either debt has decreased, or debt ceilings are not exceeded
    require(
      _deltaDebt <= 0
        || (
          collateralTypeData.debtAmount * collateralTypeData.accumulatedRate <= collateralTypeData.debtCeiling
            && globalDebt <= globalDebtCeiling
        ),
      'SAFEEngine/ceiling-exceeded'
    );
    // safe is either less risky than before, or it is safe
    require(
      (_deltaDebt <= 0 && _deltaCollateral >= 0)
        || _totalDebtIssued <= safeData.lockedCollateral * collateralTypeData.safetyPrice,
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
    require(safeData.generatedDebt == 0 || _totalDebtIssued >= collateralTypeData.debtFloor, 'SAFEEngine/dust');

    // safe didn't go above the safe debt limit
    if (_deltaDebt > 0) {
      require(safeData.generatedDebt <= safeDebtCeiling, 'SAFEEngine/above-debt-limit');
    }

    tokenCollateral[_collateralType][_collateralSource] =
      tokenCollateral[_collateralType][_collateralSource].sub(_deltaCollateral);

    coinBalance[_debtDestination] = coinBalance[_debtDestination].add(_deltaAdjustedDebt);

    safes[_collateralType][_safe] = safeData;
    collateralTypes[_collateralType] = collateralTypeData;

    emit ModifySAFECollateralization(
      _collateralType,
      _safe,
      _collateralSource,
      _debtDestination,
      _deltaCollateral,
      _deltaDebt,
      safeData.lockedCollateral,
      safeData.generatedDebt,
      globalDebt
    );
  }

  // --- SAFE Fungibility ---
  /**
   * @notice Transfer collateral and/or debt between SAFEs
   * @param _collateralType Collateral type transferred between SAFEs
   * @param _src Source SAFE
   * @param _dst Destination SAFE
   * @param _deltaCollateral Amount of collateral to take/add into src and give/take from dst (wad)
   * @param _deltaDebt Amount of debt to take/add into src and give/take from dst (wad)
   */
  function transferSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _src,
    address _dst,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external isSAFEAllowed(_src, msg.sender) isSAFEAllowed(_dst, msg.sender) {
    SAFE storage srcSAFE = safes[_collateralType][_src];
    SAFE storage dstSAFE = safes[_collateralType][_dst];
    CollateralType storage collateralType_ = collateralTypes[_collateralType];

    srcSAFE.lockedCollateral = srcSAFE.lockedCollateral.sub(_deltaCollateral);
    srcSAFE.generatedDebt = srcSAFE.generatedDebt.sub(_deltaDebt);
    dstSAFE.lockedCollateral = dstSAFE.lockedCollateral.add(_deltaCollateral);
    dstSAFE.generatedDebt = dstSAFE.generatedDebt.add(_deltaDebt);

    uint256 srcTotalDebtIssued = srcSAFE.generatedDebt * collateralType_.accumulatedRate;
    uint256 dstTotalDebtIssued = dstSAFE.generatedDebt * collateralType_.accumulatedRate;

    // both sides safe
    require(srcTotalDebtIssued <= srcSAFE.lockedCollateral * collateralType_.safetyPrice, 'SAFEEngine/not-safe-src');
    require(dstTotalDebtIssued <= dstSAFE.lockedCollateral * collateralType_.safetyPrice, 'SAFEEngine/not-safe-dst');

    // both sides non-dusty
    require(srcTotalDebtIssued >= collateralType_.debtFloor || srcSAFE.generatedDebt == 0, 'SAFEEngine/dust-src');
    require(dstTotalDebtIssued >= collateralType_.debtFloor || dstSAFE.generatedDebt == 0, 'SAFEEngine/dust-dst');
    emit TransferSAFECollateralAndDebt(
      _collateralType,
      _src,
      _dst,
      _deltaCollateral,
      _deltaDebt,
      srcSAFE.lockedCollateral,
      srcSAFE.generatedDebt,
      dstSAFE.lockedCollateral,
      dstSAFE.generatedDebt
    );
  }

  // --- SAFE Confiscation ---
  /**
   * @notice Normally used by the LiquidationEngine in order to confiscate collateral and
   *      debt from a SAFE and give them to someone else
   * @param _collateralType Collateral type the SAFE has locked inside
   * @param _safe Target SAFE
   * @param _collateralCounterparty Who we take/give collateral to
   * @param _debtCounterparty Who we take/give debt to
   * @param _deltaCollateral Amount of collateral taken/added into the SAFE (wad)
   * @param _deltaDebt Amount of debt taken/added into the SAFE (wad)
   */
  function confiscateSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _safe,
    address _collateralCounterparty,
    address _debtCounterparty,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external isAuthorized {
    SAFE storage safe_ = safes[_collateralType][_safe];
    CollateralType storage collateralType_ = collateralTypes[_collateralType];

    safe_.lockedCollateral = safe_.lockedCollateral.add(_deltaCollateral);
    safe_.generatedDebt = safe_.generatedDebt.add(_deltaDebt);
    collateralType_.debtAmount = collateralType_.debtAmount.add(_deltaDebt);

    int256 deltaTotalIssuedDebt = collateralType_.accumulatedRate.mul(_deltaDebt);

    tokenCollateral[_collateralType][_collateralCounterparty] =
      tokenCollateral[_collateralType][_collateralCounterparty].sub(_deltaCollateral);
    debtBalance[_debtCounterparty] = debtBalance[_debtCounterparty].sub(deltaTotalIssuedDebt);
    globalUnbackedDebt = globalUnbackedDebt.sub(deltaTotalIssuedDebt);

    emit ConfiscateSAFECollateralAndDebt(
      _collateralType,
      _safe,
      _collateralCounterparty,
      _debtCounterparty,
      _deltaCollateral,
      _deltaDebt,
      globalUnbackedDebt
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
   * @param _collateralType Collateral type we accrue interest for
   * @param _surplusDst Destination for the newly created surplus
   * @param _rateMultiplier Multiplier applied to the debtAmount in order to calculate the surplus [ray]
   */
  function updateAccumulatedRate(
    bytes32 _collateralType,
    address _surplusDst,
    int256 _rateMultiplier
  ) external isAuthorized {
    require(contractEnabled == 1, 'SAFEEngine/contract-not-enabled');
    CollateralType storage collateralType_ = collateralTypes[_collateralType];
    collateralType_.accumulatedRate = collateralType_.accumulatedRate.add(_rateMultiplier);
    int256 _deltaSurplus = collateralType_.debtAmount.mul(_rateMultiplier);
    coinBalance[_surplusDst] = coinBalance[_surplusDst].add(_deltaSurplus);
    globalDebt = globalDebt.add(_deltaSurplus);
    emit UpdateAccumulatedRate(_collateralType, _surplusDst, _rateMultiplier, coinBalance[_surplusDst], globalDebt);
  }

  // --- Modifiers ---
  modifier isSAFEAllowed(address _safe, address _account) {
    if (!canModifySAFE(_safe, _account)) revert NotSAFEAllowed();
    _;
  }
}
