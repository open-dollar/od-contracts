// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

interface IBasicActions is ICommonActions {
  // --- Methods ---

  /**
   * @notice Opens a brand new SAFE
   * @param  _manager Address of the ODSafeManager contract
   * @param  _cType Bytes32 representing the collateral type
   * @param  _usr Address of the SAFE owner
   * @return _safeId Id of the created SAFE
   */
  function openSAFE(address _manager, bytes32 _cType, address _usr) external returns (uint256 _safeId);

  /**
   * @notice Allow/disallow a user address to manage the safe
   * @param  _safe Id of the SAFE
   * @param  _usr Address of the user to allow/disallow
   * @param  _ok Boolean state to allow/disallow
   */
  function allowSAFE(address _manager, uint256 _safe, address _usr, bool _ok) external;
  /**
   * @notice Allow/disallow a handler address to manage the safe
   * @param  _usr Address of the user to allow/disallow
   * @param  _ok Boolean state to allow/disallow
   */
  function allowHandler(address _manager, address _usr, bool _ok) external;
  /**
   * @notice Modify a SAFE's collateralization ratio while keeping the generated COIN or collateral freed in the safe handler address
   * @param  _safe Id of the SAFE
   * @param  _deltaCollateral Delta of collateral to add/remove [wad]
   * @param  _deltaDebt Delta of debt to add/remove [wad]
   */
  function modifySAFECollateralization(
    address _manager,
    uint256 _safe,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external;
  /**
   * @notice Transfer wad amount of safe collateral from the safe address to a dst address
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst address
   * @param  _wad Amount of collateral to transfer [wad]
   */
  function transferCollateral(address _manager, uint256 _safe, address _dst, uint256 _wad) external;
  /**
   * @notice Transfer an amount of COIN from the safe address to a dst address [rad]
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst address
   * @param  _rad Amount of COIN to transfer [rad]
   */
  function transferInternalCoins(address _manager, uint256 _safe, address _dst, uint256 _rad) external;
  /**
   * @notice Quit the system, migrating the safe (lockedCollateral, generatedDebt) to a different dst handler
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst handler
   */
  function quitSystem(address _manager, uint256 _safe, address _dst) external;
  /**
   * @notice Enter the system, migrating the safe (lockedCollateral, generatedDebt) from a src handler to the safe handler
   * @param  _src Address of the src handler
   * @param  _safe Id of the SAFE
   */
  function enterSystem(address _manager, address _src, uint256 _safe) external;
  /**
   * @notice Move a position from safeSrc handler to the safeDst handler
   * @param  _safeSrc Id of the source SAFE
   * @param  _safeDst Id of the destination SAFE
   */
  function moveSAFE(address _manager, uint256 _safeSrc, uint256 _safeDst) external;
  /**
   * @notice Add a safe to the user's list of safes (doesn't set safe ownership)
   * @param  _safe Id of the SAFE
   * @dev    This function is meant to allow the user to add a safe to their list (if it was previously removed)
   */
  function addSAFE(address _manager, uint256 _safe) external;
  /**
   * @notice Remove a safe from the user's list of safes (doesn't erase safe ownership)
   * @param  _safe Id of the SAFE
   * @dev    This function is meant to allow the user to remove a safe from their list (if it was added against their will)
   */
  function removeSAFE(address _manager, uint256 _safe) external;
  /**
   * @notice Choose a safe saviour inside LiquidationEngine for the SAFE
   * @param  _safe Id of the SAFE
   * @param  _liquidationEngine Address of the LiquidationEngine
   * @param  _saviour Address of the saviour
   */
  function protectSAFE(address _manager, uint256 _safe, address _liquidationEngine, address _saviour) external;

  /**
   * @notice Generates debt and sends COIN amount to msg.sender
   * @param  _manager Address of the ODSafeManager contract
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
   * @param  _manager Address of the ODSafeManager contract
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
   * @param  _manager Address of the ODSafeManager contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _deltaWad Amount of collateral to collateralize [wad]
   */
  function lockTokenCollateral(address _manager, address _collateralJoin, uint256 _safeId, uint256 _deltaWad) external;

  /**
   * @notice Unlocks a collateral token amount from the SAFE, and transfers the ERC20 collateral to the user's address
   * @param  _manager Address of the ODSafeManager contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _safeId Id of the SAFE
   * @param  _deltaWad Amount of collateral to free [wad]
   */
  function freeTokenCollateral(address _manager, address _collateralJoin, uint256 _safeId, uint256 _deltaWad) external;

  /**
   * @notice Repays the total amount of debt of a SAFE
   * @param  _manager Address of the ODSafeManager contract
   * @param  _taxCollector Address of the TaxCollector contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _safeId Id of the SAFE
   * @dev    This method is used to close a SAFE's debt, when the amount of debt is increasing due to stability fees
   */
  function repayAllDebt(address _manager, address _taxCollector, address _coinJoin, uint256 _safeId) external;

  /**
   * @notice Locks a collateral token amount in the SAFE and generates debt
   * @param  _manager Address of the ODSafeManager contract
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
   * @param  _manager Address of the ODSafeManager contract
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
   * @param  _manager Address of the ODSafeManager contract
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
   * @param  _manager Address of the ODSafeManager contract
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
