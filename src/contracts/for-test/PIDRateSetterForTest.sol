// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PIDRateSetter} from '@contracts/PIDRateSetter.sol';

contract PIDRateSetterForTest is PIDRateSetter {
  constructor(
    address _oracleRelayer,
    address _orcl,
    address _pidCalculator,
    uint256 _updateRateDelay
  ) PIDRateSetter(_oracleRelayer, _orcl, _pidCalculator, _updateRateDelay) {}

  // Function to set the defaultLeak value for testing
  function setDefaultLeak(uint256 _defaultLeak) public {
    defaultLeak = _defaultLeak;
  }

  function setLastUpdateTime(uint256 _lastUpdateTime) public {
    lastUpdateTime = _lastUpdateTime;
  }

  function setUpdateRateDelay(uint256 _updateRateDelay) public {
    updateRateDelay = _updateRateDelay;
  }
}
