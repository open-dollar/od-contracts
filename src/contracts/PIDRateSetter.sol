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

import {IOracle as OracleLike} from '@interfaces/IOracle.sol';
import {IOracleRelayer as OracleRelayerLike} from '@interfaces/IOracleRelayer.sol';
import {IPIDController as PIDCalculator} from '@interfaces/IPIDController.sol';

import {Math, RAY} from '@libraries/Math.sol';
import {Authorizable} from '@contract-utils/Authorizable.sol';

interface IModifiable {
  function modifyParameters(bytes32 parameter, uint256 data) external;
}

contract PIDRateSetter is Authorizable {
  using Math for uint256;

  // --- Variables ---
  // When the price feed was last updated
  uint256 public lastUpdateTime; // [timestamp]
  // Enforced gap between calls
  uint256 public updateRateDelay; // [seconds]
  // Whether the leak is set to zero by default
  uint256 public defaultLeak; // [0 or 1]

  // --- System Dependencies ---
  // OSM or medianizer for the system coin
  OracleLike public orcl;
  // OracleRelayer where the redemption price is stored
  OracleRelayerLike public oracleRelayer;
  // Calculator for the redemption rate
  PIDCalculator public pidCalculator;

  // --- Events ---
  event ModifyParameters(bytes32 parameter, address addr);
  event ModifyParameters(bytes32 parameter, uint256 val);
  event UpdateRedemptionRate(uint256 marketPrice, uint256 redemptionPrice, uint256 redemptionRate);
  event FailUpdateRedemptionRate(uint256 marketPrice, uint256 redemptionPrice, uint256 redemptionRate, bytes reason);

  constructor(address _oracleRelayer, address _orcl, address _pidCalculator, uint256 _updateRateDelay) Authorizable(msg.sender) {
    require(_oracleRelayer != address(0), 'PIDRateSetter/null-oracle-relayer');
    require(_orcl != address(0), 'PIDRateSetter/null-orcl');
    require(_pidCalculator != address(0), 'PIDRateSetter/null-calculator');

    defaultLeak = 1;

    oracleRelayer = OracleRelayerLike(_oracleRelayer);
    orcl = OracleLike(_orcl);
    pidCalculator = PIDCalculator(_pidCalculator);

    updateRateDelay = _updateRateDelay;

    emit ModifyParameters('orcl', _orcl);
    emit ModifyParameters('oracleRelayer', _oracleRelayer);
    emit ModifyParameters('pidCalculator', _pidCalculator);
    emit ModifyParameters('updateRateDelay', _updateRateDelay);
  }

  // --- Management ---
  /**
   * @notice Modify the address of a contract that the setter is connected to
   * @param parameter Contract name
   * @param addr The new contract address
   */
  function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
    require(addr != address(0), 'PIDRateSetter/null-addr');
    if (parameter == 'orcl') {
      orcl = OracleLike(addr);
    } else if (parameter == 'oracleRelayer') {
      oracleRelayer = OracleRelayerLike(addr);
    } else if (parameter == 'pidCalculator') {
      pidCalculator = PIDCalculator(addr);
    } else {
      revert('PIDRateSetter/modify-unrecognized-param');
    }
    emit ModifyParameters(parameter, addr);
  }

  /**
   * @notice Modify a uint256 parameter
   * @param parameter The parameter name
   * @param val The new parameter value
   */
  function modifyParameters(bytes32 parameter, uint256 val) external isAuthorized {
    if (parameter == 'updateRateDelay') {
      require(val > 0, 'PIDRateSetter/null-update-delay');
      updateRateDelay = val;
    } else if (parameter == 'defaultLeak') {
      require(val <= 1, 'PIDRateSetter/invalid-default-leak');
      defaultLeak = val;
    } else {
      revert('PIDRateSetter/modify-unrecognized-param');
    }
    emit ModifyParameters(parameter, val);
  }

  // --- Feedback Mechanism ---
  /**
   * @notice Compute and set a new redemption rate
   */
  function updateRate() external {
    // Check delay between calls
    require(block.timestamp - lastUpdateTime >= updateRateDelay || lastUpdateTime == 0, 'PIDRateSetter/wait-more');
    // Get price feed updates
    (uint256 _marketPrice, bool _hasValidValue) = orcl.getResultWithValidity();
    // If the oracle has a value
    require(_hasValidValue, 'PIDRateSetter/invalid-oracle-value');
    // If the price is non-zero
    require(_marketPrice > 0, 'PIDRateSetter/null-price');
    // Get (and update if old) the latest redemption price
    uint256 _redemptionPrice = oracleRelayer.redemptionPrice();
    // Calculate the rate
    uint256 _iapcr = (defaultLeak == 1) ? RAY : pidCalculator.pscl().rpow(pidCalculator.tlv());
    uint256 _redemptionRate = pidCalculator.computeRate(_marketPrice, _redemptionPrice, _iapcr);
    // Store the timestamp of the update
    lastUpdateTime = block.timestamp;
    // Update the rate using the setter relayer
    // TODO: add IModifiable to IOracleRelayer when .modifyParameters is addressed
    IModifiable(address(oracleRelayer)).modifyParameters('redemptionRate', _redemptionRate);
  }

  // --- Getters ---
  /**
   * @notice Get the market price from the system coin oracle
   */
  function getMarketPrice() external view returns (uint256 _marketPrice) {
    (_marketPrice,) = orcl.getResultWithValidity();
  }

  /**
   * @notice Get the redemption and the market prices for the system coin
   */
  function getRedemptionAndMarketPrices() external returns (uint256 _marketPrice, uint256 _redemptionPrice) {
    (_marketPrice,) = orcl.getResultWithValidity();
    _redemptionPrice = oracleRelayer.redemptionPrice();
  }
}
