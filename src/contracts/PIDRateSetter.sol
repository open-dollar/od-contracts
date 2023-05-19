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
import {IOracle as OracleLike} from '@interfaces/IOracle.sol';
import {IOracleRelayer as OracleRelayerLike} from '@interfaces/IOracleRelayer.sol';
import {IPIDController as PIDCalculator} from '@interfaces/IPIDController.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Math, RAY} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';

contract PIDRateSetter is Authorizable, IPIDRateSetter {
  using Math for uint256;
  using Math for address;
  using Encoding for bytes;

  // --- Registry ---
  // OSM or medianizer for the system coin
  OracleLike public oracle;
  // OracleRelayer where the redemption price is stored
  OracleRelayerLike public oracleRelayer;
  // Calculator for the redemption rate
  PIDCalculator public pidCalculator;

  // --- Params ---
  PIDRateSetterParams internal _params;

  function params() external view returns (PIDRateSetterParams memory _pidRateSetterParams) {
    return _params;
  }

  // --- Data ---
  // When the price feed was last updated
  uint256 public lastUpdateTime; // [timestamp]

  // --- Init ---
  constructor(
    address _oracleRelayer,
    address _oracle,
    address _pidCalculator,
    uint256 _updateRateDelay
  ) Authorizable(msg.sender) {
    require(_oracleRelayer != address(0), 'PIDRateSetter/null-oracle-relayer');
    require(_oracle != address(0), 'PIDRateSetter/null-oracle');
    require(_pidCalculator != address(0), 'PIDRateSetter/null-calculator');

    oracleRelayer = OracleRelayerLike(_oracleRelayer);
    oracle = OracleLike(_oracle);
    pidCalculator = PIDCalculator(_pidCalculator);

    // TODO: require params at constructor
    _params = PIDRateSetterParams({updateRateDelay: _updateRateDelay, defaultLeak: 1});
  }

  // --- Methods ---
  /**
   * @notice Compute and set a new redemption rate
   */
  function updateRate() external {
    // Check delay between calls
    require(block.timestamp - lastUpdateTime >= _params.updateRateDelay, 'PIDRateSetter/wait-more');
    // Get price feed updates
    (uint256 _marketPrice, bool _hasValidValue) = oracle.getResultWithValidity();
    // If the oracle has a value
    require(_hasValidValue, 'PIDRateSetter/invalid-oracle-value');
    // If the price is non-zero
    require(_marketPrice > 0, 'PIDRateSetter/null-price');
    // Get (and update if old) the latest redemption price
    uint256 _redemptionPrice = oracleRelayer.redemptionPrice();
    // Calculate the rate
    uint256 _iapcr = (_params.defaultLeak == 1)
      ? RAY
      : pidCalculator.perSecondCumulativeLeak().rpow(pidCalculator.timeSinceLastUpdate());
    uint256 _redemptionRate = pidCalculator.computeRate(_marketPrice, _redemptionPrice, _iapcr);
    // Store the timestamp of the update
    lastUpdateTime = block.timestamp;
    // Update the rate using the setter relayer
    oracleRelayer.updateRedemptionRate(_redemptionRate);
  }

  // --- Getters ---
  /**
   * @notice Get the market price from the system coin oracle
   */
  function getMarketPrice() external view returns (uint256 _marketPrice) {
    (_marketPrice,) = oracle.getResultWithValidity();
  }

  /**
   * @notice Get the redemption and the market prices for the system coin
   */
  function getRedemptionAndMarketPrices() external returns (uint256 _marketPrice, uint256 _redemptionPrice) {
    (_marketPrice,) = oracle.getResultWithValidity();
    _redemptionPrice = oracleRelayer.redemptionPrice();
  }

  // --- Administration ---
  function modifyParameters(bytes32 _param, bytes memory _data) external isAuthorized {
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    if (_param == 'oracle') oracle = OracleLike(_address.assertNonNull());
    else if (_param == 'oracleRelayer') oracleRelayer = OracleRelayerLike(_address.assertNonNull());
    else if (_param == 'pidCalculator') pidCalculator = PIDCalculator(_address.assertNonNull());
    else if (_param == 'updateRateDelay') _params.updateRateDelay = _uint256.assertGt(0);
    else if (_param == 'defaultLeak') _params.defaultLeak = _uint256.assertLtEq(1);
    else revert UnrecognizedParam();

    emit ModifyParameters(_param, GLOBAL_PARAM, _data);
  }
}
