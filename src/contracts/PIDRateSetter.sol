// SPDX-License-Identifier: GPL-3.0
// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC, Reflexer Labs, INC.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {IPIDRateSetter, GLOBAL_PARAM} from '@interfaces/IPIDRateSetter.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer as OracleRelayerLike} from '@interfaces/IOracleRelayer.sol';
import {IPIDController as PIDCalculator} from '@interfaces/IPIDController.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract PIDRateSetter is Authorizable, IPIDRateSetter {
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

  // --- Registry ---
  /// @inheritdoc IPIDRateSetter
  IBaseOracle public oracle;
  /// @inheritdoc IPIDRateSetter
  OracleRelayerLike public oracleRelayer;
  /// @inheritdoc IPIDRateSetter
  PIDCalculator public pidCalculator;

  // --- Params ---
  PIDRateSetterParams internal _params;

  /// @inheritdoc IPIDRateSetter
  function params() external view returns (PIDRateSetterParams memory _pidRateSetterParams) {
    return _params;
  }

  // --- Data ---
  /// @inheritdoc IPIDRateSetter
  uint256 public lastUpdateTime;

  // --- Init ---
  constructor(
    address _oracleRelayer,
    address _oracle,
    address _pidCalculator,
    uint256 _updateRateDelay
  ) Authorizable(msg.sender) {
    oracleRelayer = OracleRelayerLike(_oracleRelayer.assertNonNull());
    oracle = IBaseOracle(_oracle.assertNonNull());
    pidCalculator = PIDCalculator(_pidCalculator.assertNonNull());
    _params.updateRateDelay = _updateRateDelay.assertGt(0);
  }

  // --- Methods ---

  /// @inheritdoc IPIDRateSetter
  function updateRate() external {
    // Check delay between calls
    if (block.timestamp - lastUpdateTime < _params.updateRateDelay) revert RateSetterCooldown();

    // Get price feed updates
    (uint256 _marketPrice, bool _hasValidValue) = oracle.getResultWithValidity();
    // Check if the oracle has a valid value and the price is non-zero
    if (!_hasValidValue || _marketPrice == 0) revert InvalidPriceFeed();

    // Get (and update if old) the latest redemption price
    uint256 _redemptionPrice = oracleRelayer.redemptionPrice();
    // Send latest redemption price to the PID calculator to calculate the redemption rate
    uint256 _redemptionRate = pidCalculator.computeRate(_marketPrice, _redemptionPrice);
    // Store the timestamp of the update
    lastUpdateTime = block.timestamp;
    // Update the rate using the setter relayer
    oracleRelayer.updateRedemptionRate(_redemptionRate);
  }

  // --- Getters ---
  /// @inheritdoc IPIDRateSetter
  function getMarketPrice() external view returns (uint256 _marketPrice) {
    (_marketPrice,) = oracle.getResultWithValidity();
  }

  /// @inheritdoc IPIDRateSetter
  function getRedemptionAndMarketPrices() external returns (uint256 _marketPrice, uint256 _redemptionPrice) {
    (_marketPrice,) = oracle.getResultWithValidity();
    _redemptionPrice = oracleRelayer.redemptionPrice();
  }

  // --- Admin ---
  function modifyParameters(bytes32 _param, bytes memory _data) external isAuthorized {
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    if (_param == 'oracle') oracle = IBaseOracle(_address.assertNonNull());
    else if (_param == 'oracleRelayer') oracleRelayer = OracleRelayerLike(_address.assertNonNull());
    else if (_param == 'pidCalculator') pidCalculator = PIDCalculator(_address.assertNonNull());
    else if (_param == 'updateRateDelay') _params.updateRateDelay = _uint256.assertGt(0);
    else revert UnrecognizedParam();

    emit ModifyParameters(_param, GLOBAL_PARAM, _data);
  }
}
