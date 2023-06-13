// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {RawPIDController} from '@contracts/for-test/RawPIDController.sol';
import {RAY} from '@libraries/Math.sol';

contract BasicRawPIDController is RawPIDController {
  constructor(
    ControllerGains memory __controllerGains,
    uint256 _perSecondCumulativeLeak,
    uint256 _integralPeriodSize,
    DeviationObservation memory _importedState
  )
    RawPIDController(
      __controllerGains,
      PIDControllerParams({
        integralPeriodSize: _integralPeriodSize,
        perSecondCumulativeLeak: _perSecondCumulativeLeak,
        noiseBarrier: 1,
        feedbackOutputUpperBound: type(uint256).max - RAY - 2,
        feedbackOutputLowerBound: -int256(RAY - 1)
      }),
      _importedState
    )
  {}

  function _breaksNoiseBarrier(uint256, uint256) internal pure override returns (bool _breaks) {
    return true;
  }

  function _getBoundedPIOutput(int256 _piOutput) internal pure override returns (int256 _boundedPIOutput) {
    return _piOutput;
  }
}
