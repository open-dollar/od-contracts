// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IOracleJob} from '@interfaces/jobs/IOracleJob.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  OracleJob
 * @notice This contract contains rewarded methods to handle the oracle relayer and the PID rate setter updates
 */
contract OracleJob is Authorizable, Modifiable, Job, IOracleJob {
  using Encoding for bytes;
  using Assertions for address;

  // --- Data ---

  /// @inheritdoc IOracleJob
  bool public shouldWorkUpdateCollateralPrice;
  /// @inheritdoc IOracleJob
  bool public shouldWorkUpdateRate;

  // --- Registry ---

  /// @inheritdoc IOracleJob
  IOracleRelayer public oracleRelayer;
  /// @inheritdoc IOracleJob
  IPIDRateSetter public pidRateSetter;

  // --- Init ---

  /**
   * @param  _oracleRelayer Address of the OracleRelayer contract
   * @param  _pidRateSetter Address of the PIDRateSetter contract
   * @param  _stabilityFeeTreasury Address of the StabilityFeeTreasury contract
   * @param  _rewardAmount Amount of tokens to reward per job transaction [wad]
   */
  constructor(
    address _oracleRelayer,
    address _pidRateSetter,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) validParams {
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    pidRateSetter = IPIDRateSetter(_pidRateSetter);

    shouldWorkUpdateCollateralPrice = true;
    shouldWorkUpdateRate = true;
  }

  // --- Job ---

  /// @inheritdoc IOracleJob
  function workUpdateCollateralPrice(bytes32 _cType) external reward {
    if (!shouldWorkUpdateCollateralPrice) revert NotWorkable();

    IDelayedOracle _delayedOracle = IDelayedOracle(address(oracleRelayer.cParams(_cType).oracle));
    if (!_delayedOracle.updateResult()) revert OracleJob_InvalidPrice();

    oracleRelayer.updateCollateralPrice(_cType);
  }

  /// @inheritdoc IOracleJob
  function workUpdateRate() external reward {
    if (!shouldWorkUpdateRate) revert NotWorkable();
    pidRateSetter.updateRate();
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override(Job, Modifiable) {
    address _address = _data.toAddress();
    bool _bool = _data.toBool();

    if (_param == 'oracleRelayer') oracleRelayer = IOracleRelayer(_address);
    else if (_param == 'pidRateSetter') pidRateSetter = IPIDRateSetter(_address);
    else if (_param == 'shouldWorkUpdateCollateralPrice') shouldWorkUpdateCollateralPrice = _bool;
    else if (_param == 'shouldWorkUpdateRate') shouldWorkUpdateRate = _bool;
    else Job._modifyParameters(_param, _data);
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override(Job, Modifiable) {
    address(oracleRelayer).assertHasCode();
    address(pidRateSetter).assertHasCode();
    Job._validateParameters();
  }
}
