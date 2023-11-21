// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

interface IGlobalSettlementActions is ICommonActions {
  // --- Methods ---

  /**
   * @notice Free remaining collateral from a SAFE after being processed by the global settlement
   * @param  _manager Address of the HaiSafeManager contract
   * @param  _globalSettlement Address of the GlobalSettlement contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _safeId Id of the SAFE to free collateral from
   * @return _collateralAmount Amount of collateral freed [wad]
   */
  function freeCollateral(
    address _manager,
    address _globalSettlement,
    address _collateralJoin,
    uint256 _safeId
  ) external returns (uint256 _collateralAmount);

  /**
   * @notice Prepare coins for redeeming
   * @param  _globalSettlement Address of the GlobalSettlement contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _coinAmount Amount of coins to prepare for redeeming [wad]
   */
  function prepareCoinsForRedeeming(address _globalSettlement, address _coinJoin, uint256 _coinAmount) external;

  /**
   * @notice Redeem collateral tokens from the global settlement
   * @param  _globalSettlement Address of the GlobalSettlement contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @return _collateralAmount Amount of collateral redeemed [wad]
   */
  function redeemCollateral(
    address _globalSettlement,
    address _collateralJoin
  ) external returns (uint256 _collateralAmount);
}
