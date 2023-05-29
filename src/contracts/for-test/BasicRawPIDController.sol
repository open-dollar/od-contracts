// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {RawPIDController} from '@contracts/for-test/RawPIDController.sol';
import {RAY} from '@libraries/Math.sol';

contract BasicRawPIDController is RawPIDController {
  constructor(
    int256 _Kp,
    int256 _Ki,
    uint256 _perSecondCumulativeLeak,
    uint256 _integralPeriodSize,
    DeviationObservation memory _importedState
  )
    RawPIDController(
      _Kp,
      _Ki,
      _perSecondCumulativeLeak,
      _integralPeriodSize,
      1,
      type(uint256).max - RAY - 2,
      -int256(RAY - 1),
      _importedState
    )
  {}

  function _breaksNoiseBarrier(uint256, uint256) internal pure override returns (bool) {
    return true;
  }

  function _getBoundedPIOutput(int256 _piOutput) internal pure override returns (int256) {
    return _piOutput;
  }
}
