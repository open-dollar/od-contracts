// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {LiquidationJob, ILiquidationJob} from '@contracts/jobs/LiquidationJob.sol';

contract LiquidationJobForTest is LiquidationJob {
  constructor(
    address _accountingEngine,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) LiquidationJob(_accountingEngine, _stabilityFeeTreasury, _rewardAmount) {}

  function setShouldWork(bool _shouldWork) external {
    shouldWork = _shouldWork;
  }
}
