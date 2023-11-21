// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

interface IBasicActions is ICommonActions {
  // --- Methods ---

  /**
   * @notice Opens a brand new SAFE
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _cType Bytes32 representing the collateral type
   * @param  _usr Address of the SAFE owner
   * @return _safeId Id of the created SAFE
   */
  function openSAFE(address _manager, bytes32 _cType, address _usr) external returns (uint256 _safeId);

  /**
   * @notice Generates debt and sends COIN amount to msg.sender
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _deltaWad Amount of COIN to generate [wad]
   */
  function generateDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external;

  /**
   * @notice Repays an amount of debt
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _deltaWad Amount of COIN to repay [wad]
   */
  function repayDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external;

  /**
   * @notice Locks a collateral token amount in the SAFE
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _deltaWad Amount of collateral to collateralize [wad]
   */
  function lockTokenCollateral(address _manager, address _collateralJoin, uint256 _safeId, uint256 _deltaWad) external;

  /**
   * @notice Unlocks a collateral token amount from the SAFE, and transfers the ERC20 collateral to the user's address
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _deltaWad Amount of collateral to free [wad]
   */
  function freeTokenCollateral(address _manager, address _collateralJoin, uint256 _safeId, uint256 _deltaWad) external;

  /**
   * @notice Repays the total amount of debt of a SAFE
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _safeId Id of the SAFE
   * @dev    This method is used to close a SAFE's debt, when the amount of debt is increasing due to stability fees
   */
  function repayAllDebt(address _manager, address _taxCollector, address _coinJoin, uint256 _safeId) external;

  /**
   * @notice Locks a collateral token amount in the SAFE and generates debt
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _safe Id of the SAFE
   * @param  _collateralAmount Amount of collateral to collateralize [wad]
   * @param  _deltaWad Amount of COIN to generate [wad]
   */
  function lockTokenCollateralAndGenerateDebt(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external;

  /**
   * @notice Creates a SAFE, locks a collateral token amount in it and generates debt
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _cType Bytes32 representing the collateral type
   * @param  _collateralAmount Amount of collateral to collateralize [wad]
   * @param  _deltaWad Amount of COIN to generate [wad]
   * @return _safe Id of the created SAFE
   */
  function openLockTokenCollateralAndGenerateDebt(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    bytes32 _cType,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external returns (uint256 _safe);

  /**
   * @notice Repays debt and unlocks a collateral token amount from the SAFE
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _collateralWad Amount of collateral to free [wad]
   * @param  _debtWad Amount of COIN to repay [wad]
   */
  function repayDebtAndFreeTokenCollateral(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralWad,
    uint256 _debtWad
  ) external;

  /**
   * @notice Repays all debt and unlocks collateral from the SAFE
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _collateralWad Amount of collateral to free [wad]
   */
  function repayAllDebtAndFreeTokenCollateral(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralWad
  ) external;
}
