// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

interface IJob {
  // --- Events ---
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  // --- Data ---
  function rewardAmount() external view returns (uint256 _rewardAmount);

  // --- Registry ---
  function stabilityFeeTreasury() external view returns (IStabilityFeeTreasury _stabilityFeeTreasury);
}
