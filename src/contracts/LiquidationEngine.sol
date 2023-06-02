// SPDX-License-Identifier: GPL-3.0
/// LiquidationEngine.sol

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

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ISAFESaviour} from '@interfaces/external/ISAFESaviour.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {ReentrancyGuard} from '@openzeppelin/security/ReentrancyGuard.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Math, RAY, WAD, MAX_RAD} from '@libraries/Math.sol';

contract LiquidationEngine is Authorizable, Modifiable, Disableable, ReentrancyGuard, ILiquidationEngine {
  using Encoding for bytes;
  using Assertions for uint256;

  // --- SAFE Saviours ---
  // Contracts that can save SAFEs from liquidation
  mapping(address => uint256) public safeSaviours;

  // Saviour contract chosen for each SAFE by its creator
  mapping(bytes32 => mapping(address => address)) public chosenSAFESaviour;

  // Current amount of system coins out for liquidation
  uint256 public currentOnAuctionSystemCoins; // [rad]

  // --- Registry ---
  ISAFEEngine public safeEngine;
  IAccountingEngine public accountingEngine;

  // --- Params ---
  LiquidationEngineParams internal _params;
  mapping(bytes32 _cType => LiquidationEngineCollateralParams) internal _cParams;

  function params() external view returns (LiquidationEngineParams memory _liqEngineParams) {
    return _params;
  }

  function cParams(bytes32 _cType) external view returns (LiquidationEngineCollateralParams memory _liqEngineCParams) {
    return _cParams[_cType];
  }

  // --- Init ---
  constructor(address _safeEngine) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine);

    _params.onAuctionSystemCoinLimit = type(uint256).max;
    emit ModifyParameters('onAuctionSystemCoinLimit', _GLOBAL_PARAM, abi.encode(type(uint256).max));
  }

  /**
   * @notice Authed function to add contracts that can save SAFEs from liquidation
   * @param  _saviour SAFE saviour contract to be whitelisted
   */
  function connectSAFESaviour(address _saviour) external isAuthorized {
    (bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward) =
      ISAFESaviour(_saviour).saveSAFE(address(this), '', address(0));
    require(_ok, 'LiquidationEngine/saviour-not-ok');
    require(
      (_collateralAdded == type(uint256).max) && (_liquidatorReward == type(uint256).max),
      'LiquidationEngine/invalid-amounts'
    );
    safeSaviours[_saviour] = 1;
    emit ConnectSAFESaviour(_saviour);
  }

  /**
   * @notice Governance used function to remove contracts that can save SAFEs from liquidation
   * @param  _saviour SAFE saviour contract to be removed
   */
  function disconnectSAFESaviour(address _saviour) external isAuthorized {
    safeSaviours[_saviour] = 0;
    emit DisconnectSAFESaviour(_saviour);
  }

  // --- SAFE Liquidation ---
  /**
   * @notice Choose a saviour contract for your SAFE
   * @param  _cType The SAFE's collateral type
   * @param  _safe The SAFE's address
   * @param  _saviour The chosen saviour
   */
  function protectSAFE(bytes32 _cType, address _safe, address _saviour) external {
    require(safeEngine.canModifySAFE(_safe, msg.sender), 'LiquidationEngine/cannot-modify-safe');
    require(_saviour == address(0) || safeSaviours[_saviour] == 1, 'LiquidationEngine/saviour-not-authorized');
    chosenSAFESaviour[_cType][_safe] = _saviour;
    emit ProtectSAFE(_cType, _safe, _saviour);
  }

  /**
   * @notice Liquidate a SAFE
   * @param  _cType The SAFE's collateral type
   * @param  _safe The SAFE's address
   */
  function liquidateSAFE(bytes32 _cType, address _safe) external whenEnabled nonReentrant returns (uint256 _auctionId) {
    uint256 _debtFloor = safeEngine.cParams(_cType).debtFloor;
    ISAFEEngine.SAFEEngineCollateralData memory _safeEngCData = safeEngine.cData(_cType);
    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(_cType, _safe);

    require(
      (_safeEngCData.liquidationPrice > 0)
        && (
          _safeData.lockedCollateral * _safeEngCData.liquidationPrice
            < _safeData.generatedDebt * _safeEngCData.accumulatedRate
        ),
      'LiquidationEngine/safe-not-unsafe'
    );
    require(
      currentOnAuctionSystemCoins < _params.onAuctionSystemCoinLimit
        && _params.onAuctionSystemCoinLimit - currentOnAuctionSystemCoins >= _debtFloor,
      'LiquidationEngine/liquidation-limit-hit'
    );

    if (chosenSAFESaviour[_cType][_safe] != address(0) && safeSaviours[chosenSAFESaviour[_cType][_safe]] == 1) {
      try ISAFESaviour(chosenSAFESaviour[_cType][_safe]).saveSAFE(msg.sender, _cType, _safe) returns (
        bool _ok, uint256 _collateralAddedOrDebtRepaid, uint256
      ) {
        if (_ok && _collateralAddedOrDebtRepaid > 0) {
          emit SaveSAFE(_cType, _safe, _collateralAddedOrDebtRepaid);
        }
      } catch (bytes memory _revertReason) {
        emit FailedSAFESave(_revertReason);
      }
    }

    // Checks that the saviour didn't take collateral or add more debt to the SAFE
    {
      ISAFEEngine.SAFE memory _newSafeData = safeEngine.safes(_cType, _safe);
      require(
        _newSafeData.lockedCollateral >= _safeData.lockedCollateral
          && _newSafeData.generatedDebt <= _safeData.generatedDebt,
        'LiquidationEngine/invalid-safe-saviour-operation'
      );
    }

    _safeEngCData = safeEngine.cData(_cType);
    _safeData = safeEngine.safes(_cType, _safe);

    if (
      (_safeEngCData.liquidationPrice > 0)
        && (
          _safeData.lockedCollateral * _safeEngCData.liquidationPrice
            < _safeData.generatedDebt * _safeEngCData.accumulatedRate
        )
    ) {
      LiquidationEngineCollateralParams memory __cParams = _cParams[_cType];

      uint256 _limitAdjustedDebt = Math.min(
        _safeData.generatedDebt,
        Math.min(__cParams.liquidationQuantity, _params.onAuctionSystemCoinLimit - currentOnAuctionSystemCoins) * WAD
          / _safeEngCData.accumulatedRate / __cParams.liquidationPenalty
      );

      require(_limitAdjustedDebt > 0, 'LiquidationEngine/null-auction');
      require(
        _limitAdjustedDebt == _safeData.generatedDebt
          || (_safeData.generatedDebt - _limitAdjustedDebt) * _safeEngCData.accumulatedRate >= _debtFloor,
        'LiquidationEngine/dusty-safe'
      );

      uint256 _collateralToSell =
        Math.min(_safeData.lockedCollateral, _safeData.lockedCollateral * _limitAdjustedDebt / _safeData.generatedDebt);

      require(_collateralToSell > 0, 'LiquidationEngine/null-collateral-to-sell');
      require(
        _collateralToSell <= 2 ** 255 && _limitAdjustedDebt <= 2 ** 255, 'LiquidationEngine/collateral-or-debt-overflow'
      );

      safeEngine.confiscateSAFECollateralAndDebt(
        _cType, _safe, address(this), address(accountingEngine), -int256(_collateralToSell), -int256(_limitAdjustedDebt)
      );
      accountingEngine.pushDebtToQueue(_limitAdjustedDebt * _safeEngCData.accumulatedRate);

      {
        // This calcuation will overflow if multiply(limitAdjustedDebt, accumulatedRate) exceeds ~10^14,
        // i.e. the maximum amountToRaise is roughly 100 trillion system coins.
        uint256 _amountToRaise = _limitAdjustedDebt * _safeEngCData.accumulatedRate * __cParams.liquidationPenalty / WAD;
        currentOnAuctionSystemCoins += _amountToRaise;

        _auctionId = ICollateralAuctionHouse(__cParams.collateralAuctionHouse).startAuction({
          _forgoneCollateralReceiver: _safe,
          _initialBidder: address(accountingEngine),
          _amountToRaise: _amountToRaise,
          _collateralToSell: _collateralToSell,
          _initialBid: 0
        });

        emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);
      }

      emit Liquidate(
        _cType,
        _safe,
        _collateralToSell,
        _limitAdjustedDebt,
        _limitAdjustedDebt * _safeEngCData.accumulatedRate,
        __cParams.collateralAuctionHouse,
        _auctionId
      );
    }
  }

  /**
   * @notice Remove debt that was being auctioned
   * @param  _rad The amount of debt to withdraw from currentOnAuctionSystemCoins
   */
  function removeCoinsFromAuction(uint256 _rad) public isAuthorized {
    currentOnAuctionSystemCoins -= _rad;
    emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);
  }

  // --- Getters ---
  /**
   * @notice Get the amount of debt that can currently be covered by a collateral auction for a specific safe
   * @param  _cType The collateral type stored in the SAFE
   * @param  _safe The SAFE's address/handler
   */
  function getLimitAdjustedDebtToCover(
    bytes32 _cType,
    address _safe
  ) external view returns (uint256 _limitAdjustedDebtToCover) {
    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    uint256 _generatedDebt = safeEngine.safes(_cType, _safe).generatedDebt;
    LiquidationEngineCollateralParams memory __cParams = _cParams[_cType];

    return Math.min(
      _generatedDebt,
      Math.min(__cParams.liquidationQuantity, _params.onAuctionSystemCoinLimit - currentOnAuctionSystemCoins) * WAD
        / _accumulatedRate / __cParams.liquidationPenalty
    );
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    if (_param == 'onAuctionSystemCoinLimit') _params.onAuctionSystemCoinLimit = _data.toUint256();
    else if (_param == 'accountingEngine') accountingEngine = abi.decode(_data, (IAccountingEngine));
    else revert UnrecognizedParam();
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'liquidationPenalty') _cParams[_cType].liquidationPenalty = _uint256;
    else if (_param == 'liquidationQuantity') _cParams[_cType].liquidationQuantity = _uint256.assertLtEq(MAX_RAD);
    else if (_param == 'collateralAuctionHouse') _setCollateralAuctionHouse(_cType, _data.toAddress());
    else revert UnrecognizedParam();
  }

  function _setCollateralAuctionHouse(bytes32 _cType, address _newCollateralAuctionHouse) internal {
    safeEngine.denySAFEModification(_cParams[_cType].collateralAuctionHouse);
    _cParams[_cType].collateralAuctionHouse = _newCollateralAuctionHouse;
    safeEngine.approveSAFEModification(_newCollateralAuctionHouse);
  }
}
