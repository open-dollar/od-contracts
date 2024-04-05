// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {OracleJob, IOracleJob} from '@contracts/jobs/OracleJob.sol';

contract OracleJobForTest is OracleJob {
  constructor(
    address _oracleRelayer,
    address _pidRateSetter,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) OracleJob(_oracleRelayer, _pidRateSetter, _stabilityFeeTreasury, _rewardAmount) {}

  function setShouldWorkUpdateCollateralPrice(bool _shouldWorkUpdateCollateralPrice) external {
    shouldWorkUpdateCollateralPrice = _shouldWorkUpdateCollateralPrice;
  }

  function setShouldWorkUpdateRate(bool _shouldWorkUpdateRate) external {
    shouldWorkUpdateRate = _shouldWorkUpdateRate;
  }
}
