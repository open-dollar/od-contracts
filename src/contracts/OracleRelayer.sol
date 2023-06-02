// SPDX-License-Identifier: GPL-3.0
/// OracleRelayer.sol

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';

contract OracleRelayer is Authorizable, Modifiable, Disableable, IOracleRelayer {
  using Encoding for bytes;
  using Math for uint256;
  using Assertions for uint256;

  // --- Registry ---
  ISAFEEngine public safeEngine;

  // --- Params ---
  OracleRelayerParams internal _params;
  mapping(bytes32 => OracleRelayerCollateralParams) internal _cParams;

  function params() external view override returns (OracleRelayerParams memory _oracleRelayerParams) {
    return _params;
  }

  function cParams(bytes32 _cType) external view returns (OracleRelayerCollateralParams memory _oracleRelayerCParams) {
    return _cParams[_cType];
  }

  // Virtual redemption price (not the most updated value)
  uint256 internal _redemptionPrice; // [ray]
  // The force that changes the system users' incentives by changing the redemption price
  uint256 public redemptionRate; // [ray]
  // Last time when the redemption price was changed
  uint256 public redemptionPriceUpdateTime; // [unix epoch time]

  // --- Init ---
  constructor(address _safeEngine) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine);
    _redemptionPrice = RAY;
    redemptionRate = RAY;
    redemptionPriceUpdateTime = block.timestamp;
    _params.redemptionRateUpperBound = RAY * WAD;
    _params.redemptionRateLowerBound = 1;
  }

  // --- Redemption Price Update ---
  /**
   * @notice Update the redemption price using the current redemption rate
   */
  function _updateRedemptionPrice() internal virtual returns (uint256 _updatedPrice) {
    // Update redemption price
    _updatedPrice = redemptionRate.rpow(block.timestamp - redemptionPriceUpdateTime).rmul(_redemptionPrice);
    if (_updatedPrice == 0) _updatedPrice = 1;
    redemptionPriceUpdateTime = block.timestamp;
    emit UpdateRedemptionPrice(_updatedPrice);
  }

  /**
   * @notice Fetch the latest redemption price by first updating it
   */
  function redemptionPrice() external returns (uint256 _updatedPrice) {
    return _getRedemptionPrice();
  }

  function _getRedemptionPrice() internal virtual returns (uint256 _updatedPrice) {
    if (block.timestamp > redemptionPriceUpdateTime) return _updateRedemptionPrice();
    return _redemptionPrice;
  }

  // --- Update value ---
  /**
   * @notice Update the collateral price inside the system (inside SAFEEngine)
   * @param  _cType The collateral we want to update prices (safety and liquidation prices) for
   */
  function updateCollateralPrice(bytes32 _cType) external {
    (uint256 _priceFeedValue, bool _hasValidValue) = _cParams[_cType].oracle.getResultWithValidity();
    uint256 _updatedRedemptionPrice = _getRedemptionPrice();

    uint256 _safetyPrice = _hasValidValue
      ? (uint256(_priceFeedValue) * uint256(10 ** 9)).rdiv(_updatedRedemptionPrice).rdiv(_cParams[_cType].safetyCRatio)
      : 0;
    uint256 _liquidationPrice = _hasValidValue
      ? (uint256(_priceFeedValue) * uint256(10 ** 9)).rdiv(_updatedRedemptionPrice).rdiv(
        _cParams[_cType].liquidationCRatio
      )
      : 0;

    safeEngine.updateCollateralPrice(_cType, _safetyPrice, _liquidationPrice);
    emit UpdateCollateralPrice(_cType, _priceFeedValue, _safetyPrice, _liquidationPrice);
  }

  function updateRedemptionRate(uint256 _redemptionRate) external isAuthorized {
    if (block.timestamp != redemptionPriceUpdateTime) revert RedemptionPriceNotUpdated();

    if (_redemptionRate > _params.redemptionRateUpperBound) {
      _redemptionRate = _params.redemptionRateUpperBound;
    } else if (_redemptionRate < _params.redemptionRateLowerBound) {
      _redemptionRate = _params.redemptionRateLowerBound;
    }
    redemptionRate = _redemptionRate;
  }

  // --- Shutdown ---
  
  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */
  function _onContractDisable() internal override {
    redemptionRate = RAY;
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override whenEnabled {
    uint256 _uint256 = _data.toUint256();

    require(_uint256 > 0, 'OracleRelayer/null-data');
    // TODO: why is there a method to update the redemptionPrice?
    if (_param == 'redemptionPrice') _redemptionPrice = _uint256;
    else if (_param == 'redemptionRateUpperBound') _params.redemptionRateUpperBound = _uint256.assertGt(RAY);
    else if (_param == 'redemptionRateLowerBound') _params.redemptionRateLowerBound = _uint256.assertLt(RAY);
    else revert UnrecognizedParam();
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override whenEnabled {
    uint256 _uint256 = _data.toUint256();
    OracleRelayerCollateralParams storage __cParams = _cParams[_cType];

    if (_param == 'safetyCRatio') __cParams.safetyCRatio = _uint256.assertGtEq(__cParams.liquidationCRatio);
    else if (_param == 'liquidationCRatio') __cParams.liquidationCRatio = _uint256.assertLtEq(__cParams.safetyCRatio);
    else if (_param == 'oracle') __cParams.oracle = abi.decode(_data, (IBaseOracle));
    else revert UnrecognizedParam();
  }
}
