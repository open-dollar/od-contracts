// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract PIDRateSetter is Authorizable, Modifiable, IPIDRateSetter {
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

  // --- Registry ---
  /// @inheritdoc IPIDRateSetter
  IBaseOracle public oracle;
  /// @inheritdoc IPIDRateSetter
  IOracleRelayer public oracleRelayer;
  /// @inheritdoc IPIDRateSetter
  IPIDController public pidCalculator;

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
    oracleRelayer = IOracleRelayer(_oracleRelayer.assertNonNull());
    oracle = IBaseOracle(_oracle.assertNonNull());
    pidCalculator = IPIDController(_pidCalculator.assertNonNull());
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

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    if (_param == 'oracle') oracle = IBaseOracle(_address.assertNonNull());
    else if (_param == 'oracleRelayer') oracleRelayer = IOracleRelayer(_address.assertNonNull());
    else if (_param == 'pidCalculator') pidCalculator = IPIDController(_address.assertNonNull());
    else if (_param == 'updateRateDelay') _params.updateRateDelay = _uint256.assertGt(0);
    else revert UnrecognizedParam();
  }
}
