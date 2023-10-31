// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';

import {IJob} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IAccountingJob is IAuthorizable, IModifiable, IJob {
  // --- Data ---

  /// @notice Whether the pop debt from queue job should be worked
  function shouldWorkPopDebtFromQueue() external view returns (bool _shouldWorkPopDebtFromQueue);

  /// @notice Whether the auction debt job should be worked
  function shouldWorkAuctionDebt() external view returns (bool _shouldWorkAuctionDebt);

  /// @notice Whether the auction surplus job should be worked
  function shouldWorkAuctionSurplus() external view returns (bool _shouldWorkAuctionSurplus);

  /// @notice Whether the transfer extra surplus job should be worked
  function shouldWorkTransferExtraSurplus() external view returns (bool _shouldWorkTransferExtraSurplus);

  // --- Registry ---

  /// @notice Address of the AccountingEngine contract
  function accountingEngine() external view returns (IAccountingEngine _accountingEngine);

  // --- Job ---

  /**
   * @notice Rewarded method to pop debt from the AccountingEngine's queue
   * @param _debtBlockTimestamp Timestamp of the debt block to pop
   */
  function workPopDebtFromQueue(uint256 _debtBlockTimestamp) external;

  /// @notice Rewarded method to auction debt from the AccountingEngine
  function workAuctionDebt() external;

  /// @notice Rewarded method to auction surplus from the AccountingEngine
  function workAuctionSurplus() external;

  /// @notice Rewarded method to transfer surplus from the AccountingEngine
  function workTransferExtraSurplus() external;
}
