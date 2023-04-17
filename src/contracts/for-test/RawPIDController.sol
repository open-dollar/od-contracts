// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PIDController} from '@contracts/PIDController.sol';
import {Math} from '@libraries/Math.sol';

contract RawPIDController is PIDController {
  using Math for uint256;
  using Math for int256;

  constructor(
    int256 Kp_,
    int256 Ki_,
    uint256 perSecondCumulativeLeak_,
    uint256 integralPeriodSize_,
    uint256 noiseBarrier_,
    uint256 feedbackOutputUpperBound_,
    int256 feedbackOutputLowerBound_,
    int256[] memory importedState
  )
    PIDController(
      Kp_,
      Ki_,
      perSecondCumulativeLeak_,
      integralPeriodSize_,
      noiseBarrier_,
      feedbackOutputUpperBound_,
      feedbackOutputLowerBound_,
      importedState
    )
  {}

  function _getProportionalTerm(
    uint256 marketPrice,
    uint256 redemptionPrice
  ) internal pure override returns (int256 _proportionalTerm) {
    // Scale the market price by 10^9 so it also has 27 decimals like the redemption price
    uint256 scaledMarketPrice = (marketPrice * 1e9);

    _proportionalTerm = redemptionPrice.sub(scaledMarketPrice);

    return _proportionalTerm;
  }
}
