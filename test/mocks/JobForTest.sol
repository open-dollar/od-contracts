// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Job, IJob} from '@contracts/jobs/Job.sol';

contract JobForTest is Job {
  constructor(
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) {}

  function rewardModifier() external reward {}
}
