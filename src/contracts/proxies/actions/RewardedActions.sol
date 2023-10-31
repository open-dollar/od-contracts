// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAccountingJob} from '@interfaces/jobs/IAccountingJob.sol';
import {ILiquidationJob} from '@interfaces/jobs/ILiquidationJob.sol';
import {IOracleJob} from '@interfaces/jobs/IOracleJob.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {IRewardedActions} from '@interfaces/proxies/actions/IRewardedActions.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title  RewardedActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract RewardedActions is CommonActions, IRewardedActions {
  // --- AccountingJob ---

  /// @inheritdoc IRewardedActions
  function startDebtAuction(address _accountingJob, address _coinJoin) external onlyDelegateCall {
    IAccountingJob(_accountingJob).workAuctionDebt();
    _exitReward(_accountingJob, _coinJoin);
  }

  /// @inheritdoc IRewardedActions
  function startSurplusAuction(address _accountingJob, address _coinJoin) external onlyDelegateCall {
    IAccountingJob(_accountingJob).workAuctionSurplus();
    _exitReward(_accountingJob, _coinJoin);
  }

  /// @inheritdoc IRewardedActions
  function popDebtFromQueue(
    address _accountingJob,
    address _coinJoin,
    uint256 _debtTimestamp
  ) external onlyDelegateCall {
    IAccountingJob(_accountingJob).workPopDebtFromQueue(_debtTimestamp);
    _exitReward(_accountingJob, _coinJoin);
  }

  /// @inheritdoc IRewardedActions
  function transferExtraSurplus(address _accountingJob, address _coinJoin) external onlyDelegateCall {
    IAccountingJob(_accountingJob).workTransferExtraSurplus();
    _exitReward(_accountingJob, _coinJoin);
  }

  // --- LiquidationJob ---

  /// @inheritdoc IRewardedActions
  function liquidateSAFE(
    address _liquidationJob,
    address _coinJoin,
    bytes32 _cType,
    address _safe
  ) external onlyDelegateCall {
    ILiquidationJob(_liquidationJob).workLiquidation(_cType, _safe);
    _exitReward(_liquidationJob, _coinJoin);
  }

  // --- OracleJob ---

  /// @inheritdoc IRewardedActions
  function updateCollateralPrice(address _oracleJob, address _coinJoin, bytes32 _cType) external onlyDelegateCall {
    IOracleJob(_oracleJob).workUpdateCollateralPrice(_cType);
    _exitReward(_oracleJob, _coinJoin);
  }

  /// @inheritdoc IRewardedActions
  function updateRedemptionRate(address _oracleJob, address _coinJoin) external onlyDelegateCall {
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
