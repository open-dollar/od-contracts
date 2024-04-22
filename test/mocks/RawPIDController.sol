// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {PIDController, IPIDController} from '@contracts/PIDController.sol';
import {Math} from '@libraries/Math.sol';

// solhint-disable
contract RawPIDController is PIDController {
  using Math for uint256;
  using Math for int256;

  constructor(
    ControllerGains memory _cGains,
    PIDControllerParams memory _pidParams,
    DeviationObservation memory _importedState
  ) PIDController(_cGains, _pidParams, _importedState) {}

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
