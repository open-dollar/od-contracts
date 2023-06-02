// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IJob} from '@interfaces/jobs/IJob.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

abstract contract Job is IJob {
  // --- Data ---
  uint256 public rewardAmount;

  // --- Registry ---
  IStabilityFeeTreasury public stabilityFeeTreasury;

  // --- Init ---
  constructor(address _stabilityFeeTreasury, uint256 _rewardAmount) {
    stabilityFeeTreasury = IStabilityFeeTreasury(_stabilityFeeTreasury);
    rewardAmount = _rewardAmount;
  }

  // --- Reward ---
  modifier reward() {
    _;
    stabilityFeeTreasury.pullFunds(msg.sender, rewardAmount);
    emit Rewarded(msg.sender, rewardAmount);
  }
}
