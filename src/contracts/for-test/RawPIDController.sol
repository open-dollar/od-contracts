// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PIDController, IPIDController} from '@contracts/PIDController.sol';
import {Math} from '@libraries/Math.sol';

// solhint-disable
contract RawPIDController is PIDController {
  using Math for uint256;
  using Math for int256;

  constructor(
    ControllerGains memory __controllerGains,
    PIDControllerParams memory __params,
    DeviationObservation memory _importedState
  ) PIDController(__controllerGains, __params, _importedState) {}

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
