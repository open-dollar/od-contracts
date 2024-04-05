// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Job, IJob} from '@contracts/jobs/Job.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

contract JobForTest is Job {
  constructor(
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) validParams {}

  function rewardModifier() external reward {}
}
