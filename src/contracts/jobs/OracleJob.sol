// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOracleJob} from '@interfaces/jobs/IOracleJob.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';

contract OracleJob is Job, Authorizable, Modifiable, IOracleJob {
  using Encoding for bytes;

  // --- Data ---
  bool public shouldWorkUpdateCollateralPrice;
  bool public shouldWorkUpdateRate;

  // --- Registry ---
  IOracleRelayer public oracleRelayer;
  IPIDRateSetter public pidRateSetter;

  // --- Init ---
  constructor(
    address _oracleRelayer,
    address _pidRateSetter,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) {
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    pidRateSetter = IPIDRateSetter(_pidRateSetter);

    shouldWorkUpdateCollateralPrice = true;
    shouldWorkUpdateRate = true;
  }

  // --- Job ---
  function workUpdateCollateralPrice(bytes32 _cType) external reward {
    if (!shouldWorkUpdateCollateralPrice) revert NotWorkable();

    IDelayedOracle _delayedOracle = IDelayedOracle(address(oracleRelayer.cParams(_cType).oracle));
    if (!_delayedOracle.updateResult()) revert InvalidPrice();

    oracleRelayer.updateCollateralPrice(_cType);
  }

  function workUpdateRate() external reward {
    if (!shouldWorkUpdateRate) revert NotWorkable();
    pidRateSetter.updateRate();
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    bool _bool = _data.toBool();

    if (_param == 'oracleRelayer') oracleRelayer = IOracleRelayer(_address);
    else if (_param == 'pidRateSetter') pidRateSetter = IPIDRateSetter(_address);
    else if (_param == 'stabilityFeeTreasury') stabilityFeeTreasury = IStabilityFeeTreasury(_address);
    else if (_param == 'shouldWorkUpdateCollateralPrice') shouldWorkUpdateCollateralPrice = _bool;
    else if (_param == 'shouldWorkUpdateRate') shouldWorkUpdateRate = _bool;
    else if (_param == 'rewardAmount') rewardAmount = _data.toUint256();
    else revert UnrecognizedParam();
  }
}
