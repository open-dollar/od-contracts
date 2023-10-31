// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiSafeManager} from '@contracts/proxies/HaiSafeManager.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IBasicActions} from '@interfaces/proxies/actions/IBasicActions.sol';

import {Math, WAD, RAY, RAD} from '@libraries/Math.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

/**
 * @title  BasicActions
 * @notice This contract defines the actions that can be executed to manage a SAFE
 */
contract BasicActions is CommonActions, IBasicActions {
  using Math for uint256;

  // --- Internal functions ---

  /**
   * @notice Gets delta debt generated for delta wad (always positive)
   * @dev    Total SAFE debt minus available safeHandler COIN balance
   */
  function _getGeneratedDeltaDebt(
    address _safeEngine,
    bytes32 _cType,
    address _safeHandler,
    uint256 _deltaWad
  ) internal view returns (int256 _deltaDebt) {
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    uint256 _coinAmount = ISAFEEngine(_safeEngine).coinBalance(_safeHandler);

    // If there was already enough COIN in the safeEngine balance, just exits it without adding more debt
    if (_coinAmount < _deltaWad * RAY) {
      // Calculates the needed deltaDebt so together with the existing coins in the safeEngine is enough to exit wad amount of COIN tokens
      _deltaDebt = ((_deltaWad * RAY - _coinAmount) / _rate).toInt();
      // This is neeeded due lack of precision. It might need to sum an extra deltaDebt wei (for the given COIN wad amount)
      _deltaDebt = uint256(_deltaDebt) * _rate < _deltaWad * RAY ? _deltaDebt + 1 : _deltaDebt;
    }
  }

  /**
   * @notice Gets repaid delta debt generated
   * @dev    The rate adjusted debt of the SAFE
   */
  function _getRepaidDeltaDebt(
    address _safeEngine,
    bytes32 _cType,
    address _safeHandler
  ) internal view returns (int256 _deltaDebt) {
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    uint256 _generatedDebt = ISAFEEngine(_safeEngine).safes(_cType, _safeHandler).generatedDebt;
    uint256 _coinAmount = ISAFEEngine(_safeEngine).coinBalance(_safeHandler);

    // Uses the whole coin balance in the safeEngine to reduce the debt
    _deltaDebt = (_coinAmount / _rate).toInt();
    // Checks the calculated deltaDebt is not higher than safe.generatedDebt (total debt), otherwise uses its value
    _deltaDebt = uint256(_deltaDebt) <= _generatedDebt ? -_deltaDebt : -_generatedDebt.toInt();
  }

  /**
   * @notice Gets repaid debt
   * @dev    The rate adjusted SAFE's debt minus COIN balance available in usr's address
   */
  function _getRepaidDebt(
    address _safeEngine,
    address _usr,
    bytes32 _cType,
    address _safeHandler
  ) internal view returns (uint256 _deltaWad) {
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    uint256 _generatedDebt = ISAFEEngine(_safeEngine).safes(_cType, _safeHandler).generatedDebt;
    uint256 _coinAmount = ISAFEEngine(_safeEngine).coinBalance(_usr);

    // Uses the whole coin balance in the safeEngine to reduce the debt
    uint256 _rad = _generatedDebt * _rate - _coinAmount;
    // Calculates the equivalent COIN amount
    _deltaWad = _rad / RAY;
    // If the rad precision has some dust, it will need to request for 1 extra wad wei
    _deltaWad = _deltaWad * RAY < _rad ? _deltaWad + 1 : _deltaWad;
  }

  /**
   * @notice Generates debt
   * @dev    Modifies the SAFE collateralization ratio, increasing the debt and sends the COIN amount to the user's address
   */
  function _generateDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) internal {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);
    ITaxCollector(_taxCollector).taxSingle(_safeInfo.collateralType);

    // Generates debt in the SAFE
    _modifySAFECollateralization(
      _manager,
      _safeId,
      0,
      _getGeneratedDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler, _deltaWad)
    );

    // Moves the COIN amount to user's address
    _collectAndExitCoins(_manager, _coinJoin, _safeId, _deltaWad);
  }

  /**
   * @notice Repays debt
   * @dev    Joins COIN amount into the safeEngine and modifies the SAFE collateralization reducing the debt
   */
  function _repayDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) internal {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);
    ITaxCollector(_taxCollector).taxSingle(_safeInfo.collateralType);

    // Joins COIN amount into the safeEngine
    _joinSystemCoins(_coinJoin, _safeInfo.safeHandler, _deltaWad);

    // Paybacks debt to the SAFE
    _modifySAFECollateralization(
      _manager, _safeId, 0, _getRepaidDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler)
    );
  }

  /// @notice Routes the openSAFE call to the HaiSafeManager contract
  function _openSAFE(address _manager, bytes32 _cType, address _usr) internal returns (uint256 _safeId) {
    _safeId = HaiSafeManager(_manager).openSAFE(_cType, _usr);
  }

  /// @notice Routes the transferCollateral call to the HaiSafeManager contract
  function _transferCollateral(address _manager, uint256 _safeId, address _dst, uint256 _deltaWad) internal {
    if (_deltaWad == 0) return;
    HaiSafeManager(_manager).transferCollateral(_safeId, _dst, _deltaWad);
  }

  /// @notice Routes the transferInternalCoins call to the HaiSafeManager contract
  function _transferInternalCoins(address _manager, uint256 _safeId, address _dst, uint256 _rad) internal {
    HaiSafeManager(_manager).transferInternalCoins(_safeId, _dst, _rad);
  }

  /// @notice Routes the modifySAFECollateralization call to the HaiSafeManager contract
  function _modifySAFECollateralization(
    address _manager,
    uint256 _safeId,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) internal {
    HaiSafeManager(_manager).modifySAFECollateralization(_safeId, _deltaCollateral, _deltaDebt);
  }

  /**
   * @notice Joins collateral and exits an amount of COIN
   */
  function _lockTokenCollateralAndGenerateDebt(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) internal {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);
    ITaxCollector(_taxCollector).taxSingle(_safeInfo.collateralType);

    // Takes token amount from user's wallet and joins into the safeEngine
    _joinCollateral(_collateralJoin, _safeInfo.safeHandler, _collateralAmount);

    // Locks token amount into the SAFE and generates debt
    _modifySAFECollateralization(
      _manager,
      _safeId,
      _collateralAmount.toInt(),
      _getGeneratedDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler, _deltaWad)
    );

    // Exits and transfers COIN amount to the user's address
    _collectAndExitCoins(_manager, _coinJoin, _safeId, _deltaWad);
  }

  /**
   * @notice Transfers an amount of COIN to the proxy address and exits to the user's address
   */
  function _collectAndExitCoins(address _manager, address _coinJoin, uint256 _safeId, uint256 _deltaWad) internal {
    // Moves the COIN amount to proxy's address
    _transferInternalCoins(_manager, _safeId, address(this), _deltaWad * RAY);
    // Exits the COIN amount to the user's address
    _exitSystemCoins(_coinJoin, _deltaWad * RAY);
  }

  /**
   * @notice Transfers an amount of collateral to the proxy address and exits collateral tokens to the user
   */
  function _collectAndExitCollateral(
    address _manager,
    address _collateralJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) internal {
    // Moves the amount from the SAFE handler to proxy's address
    _transferCollateral(_manager, _safeId, address(this), _deltaWad);
    // Exits a rounded down amount of collateral
    _exitCollateral(_collateralJoin, _deltaWad);
  }

  // --- Methods ---

  /// @inheritdoc IBasicActions
  function openSAFE(address _manager, bytes32 _cType, address _usr) external onlyDelegateCall returns (uint256 _safeId) {
    return _openSAFE(_manager, _cType, _usr);
  }

  /// @inheritdoc IBasicActions
  function generateDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external onlyDelegateCall {
    _generateDebt(_manager, _taxCollector, _coinJoin, _safeId, _deltaWad);
  }

  /// @inheritdoc IBasicActions
  function repayDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external onlyDelegateCall {
    _repayDebt(_manager, _taxCollector, _coinJoin, _safeId, _deltaWad);
  }

  /// @inheritdoc IBasicActions
  function lockTokenCollateral(
    address _manager,
    address _collateralJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external onlyDelegateCall {
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);

    // Takes token amount from user's wallet and joins into the safeEngine
    _joinCollateral(_collateralJoin, _safeInfo.safeHandler, _deltaWad);

    // Locks token amount in the safe
    _modifySAFECollateralization(_manager, _safeId, _deltaWad.toInt(), 0);
  }

  /// @inheritdoc IBasicActions
  function freeTokenCollateral(
    address _manager,
    address _collateralJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external onlyDelegateCall {
    // Unlocks token amount from the SAFE
    _modifySAFECollateralization(_manager, _safeId, -_deltaWad.toInt(), 0);
    // Transfers token amount to the user's address
    _collectAndExitCollateral(_manager, _collateralJoin, _safeId, _deltaWad);
  }

  /// @inheritdoc IBasicActions
  function repayAllDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId
  ) external onlyDelegateCall {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);
    ITaxCollector(_taxCollector).taxSingle(_safeInfo.collateralType);

    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_safeInfo.collateralType, _safeInfo.safeHandler);

    // Joins COIN amount into the safeEngine
    _joinSystemCoins(
      _coinJoin,
      address(this),
      _getRepaidDebt(_safeEngine, address(this), _safeInfo.collateralType, _safeInfo.safeHandler)
    );

    // Paybacks debt to the SAFE (allowed because reducing debt of the SAFE)
    ISAFEEngine(_safeEngine).modifySAFECollateralization({
      _cType: _safeInfo.collateralType,
      _safe: _safeInfo.safeHandler,
      _collateralSource: address(this),
      _debtDestination: address(this),
      _deltaCollateral: 0,
      _deltaDebt: -_safeData.generatedDebt.toInt()
    });
  }

  /// @inheritdoc IBasicActions
  function lockTokenCollateralAndGenerateDebt(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external onlyDelegateCall {
    _lockTokenCollateralAndGenerateDebt(
      _manager, _taxCollector, _collateralJoin, _coinJoin, _safe, _collateralAmount, _deltaWad
    );
  }

  /// @inheritdoc IBasicActions
  function openLockTokenCollateralAndGenerateDebt(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    bytes32 _cType,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external onlyDelegateCall returns (uint256 _safe) {
    _safe = _openSAFE(_manager, _cType, address(this));

    _lockTokenCollateralAndGenerateDebt(
      _manager, _taxCollector, _collateralJoin, _coinJoin, _safe, _collateralAmount, _deltaWad
    );
  }

  /// @inheritdoc IBasicActions
  function repayDebtAndFreeTokenCollateral(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralWad,
    uint256 _debtWad
  ) external onlyDelegateCall {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);
    ITaxCollector(_taxCollector).taxSingle(_safeInfo.collateralType);

    // Joins COIN amount into the safeEngine
    _joinSystemCoins(_coinJoin, _safeInfo.safeHandler, _debtWad);

    // Paybacks debt to the SAFE and unlocks token amount from it
    _modifySAFECollateralization(
      _manager,
      _safeId,
      -_collateralWad.toInt(),
      _getRepaidDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler)
    );

    // Transfers token amount to the user's address
    _collectAndExitCollateral(_manager, _collateralJoin, _safeId, _collateralWad);
  }

  /// @inheritdoc IBasicActions
  function repayAllDebtAndFreeTokenCollateral(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralWad
  ) external onlyDelegateCall {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);
    ITaxCollector(_taxCollector).taxSingle(_safeInfo.collateralType);

    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_safeInfo.collateralType, _safeInfo.safeHandler);

    // Joins COIN amount into the safeEngine
    _joinSystemCoins(
      _coinJoin,
      _safeInfo.safeHandler,
      _getRepaidDebt(_safeEngine, _safeInfo.safeHandler, _safeInfo.collateralType, _safeInfo.safeHandler)
    );

    // Paybacks debt to the SAFE and unlocks token amount from it
    _modifySAFECollateralization(_manager, _safeId, -_collateralWad.toInt(), -_safeData.generatedDebt.toInt());

    // Transfers token amount to the user's address
    _collectAndExitCollateral(_manager, _collateralJoin, _safeId, _collateralWad);
  }
}
