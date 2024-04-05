// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AccountingJob, IAccountingJob} from '@contracts/jobs/AccountingJob.sol';

contract AccountingJobForTest is AccountingJob {
  constructor(
    address _accountingEngine,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) AccountingJob(_accountingEngine, _stabilityFeeTreasury, _rewardAmount) {}

  function setShouldWorkPopDebtFromQueue(bool _shouldWorkPopDebtFromQueue) external {
    shouldWorkPopDebtFromQueue = _shouldWorkPopDebtFromQueue;
  }

  function setShouldWorkAuctionDebt(bool _shouldWorkAuctionDebt) external {
    shouldWorkAuctionDebt = _shouldWorkAuctionDebt;
  }

  function setShouldWorkAuctionSurplus(bool _shouldWorkAuctionSurplus) external {
    shouldWorkAuctionSurplus = _shouldWorkAuctionSurplus;
  }

  function setShouldWorkTransferExtraSurplus(bool _shouldWorkTransferExtraSurplus) external {
    shouldWorkTransferExtraSurplus = _shouldWorkTransferExtraSurplus;
  }
}
