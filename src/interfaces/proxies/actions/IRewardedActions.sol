// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

interface IRewardedActions is ICommonActions {
  // --- AccountingJob ---

  /**
   * @notice Starts a debt auction and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function startDebtAuction(address _accountingJob, address _coinJoin) external;

  /**
   * @notice Starts a surplus auction and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function startSurplusAuction(address _accountingJob, address _coinJoin) external;

  /**
   * @notice Pops debt from accounting engine's queue and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _debtTimestamp Timestamp of the debt to pop from the queue
   */
  function popDebtFromQueue(address _accountingJob, address _coinJoin, uint256 _debtTimestamp) external;

  /**
   * @notice Transfers surplus from accounting engine and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function transferExtraSurplus(address _accountingJob, address _coinJoin) external;

  // --- LiquidationJob ---

  /**
   * @notice Starts a liquidation and transfers the reward to the user
   * @param  _liquidationJob Address of the LiquidationJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safe Address of the SAFE to liquidate
   */
  function liquidateSAFE(address _liquidationJob, address _coinJoin, bytes32 _cType, address _safe) external;

  // --- OracleJob ---

  /**
   * @notice Updates the price of a collateral type and transfers the reward to the user
   * @param  _oracleJob Address of the OracleJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _cType Bytes32 representation of the collateral type
   */
  function updateCollateralPrice(address _oracleJob, address _coinJoin, bytes32 _cType) external;

  /**
   * @notice Updates the redemption rate and transfers the reward to the user
   * @param  _oracleJob Address of the OracleJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function updateRedemptionRate(address _oracleJob, address _coinJoin) external;
}
