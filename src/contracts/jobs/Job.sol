// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IJob} from '@interfaces/jobs/IJob.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

/**
 * @title  Job Abstract Contract
 * @notice This abstract contract is inherited by all jobs to add a reward modifier
 */
abstract contract Job is IJob {
  // --- Data ---

  /// @inheritdoc IJob
  uint256 public rewardAmount;

  // --- Registry ---

  /// @inheritdoc IJob
  IStabilityFeeTreasury public stabilityFeeTreasury;

  // --- Init ---

  /**
   *
   * @param  _stabilityFeeTreasury Address of the StabilityFeeTreasury contract
   * @param  _rewardAmount Amount of tokens to reward per job transaction [wad]
   */
  constructor(address _stabilityFeeTreasury, uint256 _rewardAmount) {
    stabilityFeeTreasury = IStabilityFeeTreasury(_stabilityFeeTreasury);
    rewardAmount = _rewardAmount;
  }

  // --- Reward ---

  /// @notice Modifier to reward the caller for calling the function
  modifier reward() {
    _;
    stabilityFeeTreasury.pullFunds(msg.sender, rewardAmount);
    emit Rewarded(msg.sender, rewardAmount);
  }
}
