// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IJob is IAuthorizable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when a reward is issued
   * @param _rewardedAccount Account that received the reward
   * @param _rewardAmount Amount of reward issued [wad]
   */
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  // --- Errors ---

  /// @notice Throws when trying to call a not-workable job function
  error NotWorkable();

  // --- Data ---

  /// @notice Amount of tokens to reward per job transaction [wad]
  function rewardAmount() external view returns (uint256 _rewardAmount);

  // --- Registry ---

  /// @notice Address of the StabilityFeeTreasury contract
  function stabilityFeeTreasury() external view returns (IStabilityFeeTreasury _stabilityFeeTreasury);
}
