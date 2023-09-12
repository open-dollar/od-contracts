// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ILiquidationJob} from '@interfaces/jobs/ILiquidationJob.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';

/**
 * @title  LiquidationJob
 * @notice This contract contains rewarded methods to handle the SAFE liquidations
 */
contract LiquidationJob is Job, Authorizable, Modifiable, ILiquidationJob {
  using Encoding for bytes;

  // --- Data ---

  /// @inheritdoc ILiquidationJob
  bool public shouldWork;

  // --- Registry ---

  /// @inheritdoc ILiquidationJob
  ILiquidationEngine public liquidationEngine;

  // --- Init ---

  /**
   * @param  _liquidationEngine Address of the LiquidationEngine contract
   * @param  _stabilityFeeTreasury Address of the StabilityFeeTreasury contract
   * @param  _rewardAmount Amount of tokens to reward per job transaction [wad]
   */
  constructor(
    address _liquidationEngine,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) {
    liquidationEngine = ILiquidationEngine(_liquidationEngine);

    shouldWork = true;
  }

  // --- Job ---

  /// @inheritdoc ILiquidationJob
  function workLiquidation(bytes32 _cType, address _safe) external reward {
    if (!shouldWork) revert NotWorkable();
    liquidationEngine.liquidateSAFE(_cType, _safe);
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();

    if (_param == 'liquidationEngine') liquidationEngine = ILiquidationEngine(_address);
    else if (_param == 'stabilityFeeTreasury') stabilityFeeTreasury = IStabilityFeeTreasury(_address);
    else if (_param == 'shouldWork') shouldWork = _data.toBool();
    else if (_param == 'rewardAmount') rewardAmount = _data.toUint256();
    else revert UnrecognizedParam();
  }
}
