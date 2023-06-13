// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';

import {IJob, IStabilityFeeTreasury} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IAccountingJob is IJob, IAuthorizable, IModifiable {
  // --- Errors ---
  error NotWorkable();

  // --- Data ---
  function shouldWorkPopDebtFromQueue() external view returns (bool _shouldWorkPopDebtFromQueue);
  function shouldWorkAuctionDebt() external view returns (bool _shouldWorkAuctionDebt);
  function shouldWorkAuctionSurplus() external view returns (bool _shouldWorkAuctionSurplus);
  function shouldWorkTransferExtraSurplus() external view returns (bool _shouldWorkTransferExtraSurplus);

  // --- Registry ---
  function accountingEngine() external view returns (IAccountingEngine _accountingEngine);

  // --- Job ---
  function workPopDebtFromQueue(uint256 _debtBlockTimestamp) external;
  function workAuctionDebt() external;
  function workAuctionSurplus() external;
  function workTransferExtraSurplus() external;
}
