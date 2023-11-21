// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IJob} from '@interfaces/jobs/IJob.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  Job Abstract Contract
 * @notice This abstract contract is inherited by all jobs to add a reward modifier
 */
abstract contract Job is Authorizable, Modifiable, IJob {
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

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

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal virtual override {
    if (_param == 'stabilityFeeTreasury') stabilityFeeTreasury = IStabilityFeeTreasury(_data.toAddress());
    else if (_param == 'rewardAmount') rewardAmount = _data.toUint256();
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view virtual override {
    address(stabilityFeeTreasury).assertHasCode();
    rewardAmount.assertNonNull();
  }

  // --- Reward ---

  /// @notice Modifier to reward the caller for calling the function
  modifier reward() {
    _;
    stabilityFeeTreasury.pullFunds(msg.sender, rewardAmount);
    emit Rewarded(msg.sender, rewardAmount);
  }
}
