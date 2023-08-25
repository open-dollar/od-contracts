// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingJob} from '@interfaces/jobs/IAccountingJob.sol';
import {ILiquidationJob} from '@interfaces/jobs/ILiquidationJob.sol';
import {IOracleJob} from '@interfaces/jobs/IOracleJob.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title  RewardedActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract RewardedActions is CommonActions {
  // --- AccountingJob ---

  /**
   * @notice Starts a debt auction and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function startDebtAuction(address _accountingJob, address _coinJoin) external delegateCall {
    IAccountingJob(_accountingJob).workAuctionDebt();
    _exitReward(_accountingJob, _coinJoin);
  }

  /**
   * @notice Starts a surplus auction and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function startSurplusAuction(address _accountingJob, address _coinJoin) external delegateCall {
    IAccountingJob(_accountingJob).workAuctionSurplus();
    _exitReward(_accountingJob, _coinJoin);
  }

  /**
   * @notice Pops debt from accounting engine's queue and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _debtTimestamp Timestamp of the debt to pop from the queue
   */
  function popDebtFromQueue(address _accountingJob, address _coinJoin, uint256 _debtTimestamp) external delegateCall {
    IAccountingJob(_accountingJob).workPopDebtFromQueue(_debtTimestamp);
    _exitReward(_accountingJob, _coinJoin);
  }

  /**
   * @notice Transfers surplus from accounting engine and transfers the reward to the user
   * @param  _accountingJob Address of the AccountingJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function transferExtraSurplus(address _accountingJob, address _coinJoin) external delegateCall {
    IAccountingJob(_accountingJob).workTransferExtraSurplus();
    _exitReward(_accountingJob, _coinJoin);
  }

  // --- LiquidationJob ---

  /**
   * @notice Starts a liquidation and transfers the reward to the user
   * @param  _liquidationJob Address of the LiquidationJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safe Address of the SAFE to liquidate
   */
  function liquidateSAFE(
    address _liquidationJob,
    address _coinJoin,
    bytes32 _cType,
    address _safe
  ) external delegateCall {
    ILiquidationJob(_liquidationJob).workLiquidation(_cType, _safe);
    _exitReward(_liquidationJob, _coinJoin);
  }

  // --- OracleJob ---

  /**
   * @notice Updates the price of a collateral type and transfers the reward to the user
   * @param  _oracleJob Address of the OracleJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _cType Bytes32 representation of the collateral type
   */
  function updateCollateralPrice(address _oracleJob, address _coinJoin, bytes32 _cType) external delegateCall {
    IOracleJob(_oracleJob).workUpdateCollateralPrice(_cType);
    _exitReward(_oracleJob, _coinJoin);
  }

  /**
   * @notice Updates the redemption rate and transfers the reward to the user
   * @param  _oracleJob Address of the OracleJob contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function updateRedemptionRate(address _oracleJob, address _coinJoin) external delegateCall {
    IOracleJob(_oracleJob).workUpdateRate();
    _exitReward(_oracleJob, _coinJoin);
  }

  // --- Internal functions ---

  /**
   * @notice Exits the reward from the job and transfers it to the user
   * @param  _job Address of the job contract
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function _exitReward(address _job, address _coinJoin) internal {
    uint256 _rewardAmount = IJob(_job).rewardAmount();
    _exitSystemCoins(_coinJoin, _rewardAmount * RAY);
  }
}
