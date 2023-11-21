// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  PIDRateSetter
 * @notice This contract is used to trigger the update of the redemption rate using the PID controller
 */
contract PIDRateSetter is Authorizable, Modifiable, IPIDRateSetter {
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc IPIDRateSetter
  IOracleRelayer public oracleRelayer;
  /// @inheritdoc IPIDRateSetter
  IPIDController public pidCalculator;

  // --- Params ---

  /// @inheritdoc IPIDRateSetter
  // solhint-disable-next-line private-vars-leading-underscore
  PIDRateSetterParams public _params;

  /// @inheritdoc IPIDRateSetter
  function params() external view returns (PIDRateSetterParams memory _pidRateSetterParams) {
    return _params;
  }

  // --- Data ---

  /// @inheritdoc IPIDRateSetter
  uint256 public lastUpdateTime;

  // --- Init ---

  /**
   * @param  _oracleRelayer Address of the oracle relayer
   * @param  _pidCalculator Address of the PID calculator
   * @param  _pidRateSetterParams Initial valid PID rate setter parameters struct
   */
  constructor(
    address _oracleRelayer,
    address _pidCalculator,
    PIDRateSetterParams memory _pidRateSetterParams
  ) Authorizable(msg.sender) validParams {
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    pidCalculator = IPIDController(_pidCalculator);
    _params = _pidRateSetterParams;
  }

  // --- Methods ---

  /// @inheritdoc IPIDRateSetter
  function updateRate() external {
    // Check delay between calls
    if (block.timestamp - lastUpdateTime < _params.updateRateDelay) revert PIDRateSetter_RateSetterCooldown();

    // Get market price and check if it's non-zero
    uint256 _marketPrice = oracleRelayer.marketPrice();
    if (_marketPrice == 0) revert PIDRateSetter_InvalidPriceFeed();

    // Get (and update if old) the latest redemption price
    uint256 _redemptionPrice = oracleRelayer.redemptionPrice();

    // Send latest redemption price to the PID calculator to calculate the redemption rate
    uint256 _redemptionRate = pidCalculator.computeRate(_marketPrice, _redemptionPrice);

    // Store the timestamp of the update
    lastUpdateTime = block.timestamp;

    // Update the rate using the setter relayer
    oracleRelayer.updateRedemptionRate(_redemptionRate);
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    if (_param == 'oracleRelayer') oracleRelayer = IOracleRelayer(_address);
    else if (_param == 'pidCalculator') pidCalculator = IPIDController(_address);
    else if (_param == 'updateRateDelay') _params.updateRateDelay = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    _params.updateRateDelay.assertGt(0);

    address(oracleRelayer).assertHasCode();
    address(pidCalculator).assertHasCode();
  }
}
