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

import {Math, RAY, WAD} from '@libraries/Math.sol';

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {IOracle as OracleLike} from '@interfaces/IOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

contract OracleRelayer is Authorizable, Disableable, IOracleRelayer {
  using Math for uint256;

  // Data about each collateral type
  mapping(bytes32 => CollateralType) public collateralTypes;

  SAFEEngineLike public safeEngine;

  // Virtual redemption price (not the most updated value)
  uint256 internal _redemptionPrice; // [ray]
  // The force that changes the system users' incentives by changing the redemption price
  uint256 public redemptionRate; // [ray]
  // Last time when the redemption price was changed
  uint256 public redemptionPriceUpdateTime; // [unix epoch time]
  // Upper bound for the per-second redemption rate
  uint256 public redemptionRateUpperBound; // [ray]
  // Lower bound for the per-second redemption rate
  uint256 public redemptionRateLowerBound; // [ray]

  // --- Init ---
  constructor(address _safeEngine) Authorizable(msg.sender) {
    safeEngine = SAFEEngineLike(_safeEngine);
    _redemptionPrice = RAY;
    redemptionRate = RAY;
    redemptionPriceUpdateTime = block.timestamp;
    redemptionRateUpperBound = RAY * WAD;
    redemptionRateLowerBound = 1;
  }

  // --- Administration ---
  /**
   * @notice Modify oracle price feed addresses
   * @param  _collateralType Collateral whose oracle we change
   * @param  _parameter Name of the parameter
   * @param  _addr New oracle address
   */
  function modifyParameters(
    bytes32 _collateralType,
    bytes32 _parameter,
    address _addr
  ) external isAuthorized whenEnabled {
    if (_parameter == 'orcl') collateralTypes[_collateralType].orcl = OracleLike(_addr);
    else revert('OracleRelayer/modify-unrecognized-param');
    emit ModifyParameters(_collateralType, _parameter, _addr);
  }

  /**
   * @notice Modify redemption rate/price related parameters
   * @param  _parameter Name of the parameter
   * @param  _data New param value
   */
  function modifyParameters(bytes32 _parameter, uint256 _data) external isAuthorized whenEnabled {
    require(_data > 0, 'OracleRelayer/null-data');
    if (_parameter == 'redemptionPrice') {
      _redemptionPrice = _data;
    } else if (_parameter == 'redemptionRate') {
      require(block.timestamp == redemptionPriceUpdateTime, 'OracleRelayer/redemption-price-not-updated');
      uint256 adjustedRate = _data;
      if (_data > redemptionRateUpperBound) {
        adjustedRate = redemptionRateUpperBound;
      } else if (_data < redemptionRateLowerBound) {
        adjustedRate = redemptionRateLowerBound;
      }
      redemptionRate = adjustedRate;
    } else if (_parameter == 'redemptionRateUpperBound') {
      require(_data > RAY, 'OracleRelayer/invalid-redemption-rate-upper-bound');
      redemptionRateUpperBound = _data;
    } else if (_parameter == 'redemptionRateLowerBound') {
      require(_data < RAY, 'OracleRelayer/invalid-redemption-rate-lower-bound');
      redemptionRateLowerBound = _data;
    } else {
      revert('OracleRelayer/modify-unrecognized-param');
    }
    emit ModifyParameters(_parameter, _data);
  }

  /**
   * @notice Modify CRatio related parameters
   * @param  _collateralType Collateral whose parameters we change
   * @param  _parameter Name of the parameter
   * @param  _data New param value
   */
  function modifyParameters(
    bytes32 _collateralType,
    bytes32 _parameter,
    uint256 _data
  ) external isAuthorized whenEnabled {
    if (_parameter == 'safetyCRatio') {
      require(
        _data >= collateralTypes[_collateralType].liquidationCRatio,
        'OracleRelayer/safety-lower-than-liquidation-cratio'
      );
      collateralTypes[_collateralType].safetyCRatio = _data;
    } else if (_parameter == 'liquidationCRatio') {
      require(
        _data <= collateralTypes[_collateralType].safetyCRatio, 'OracleRelayer/safety-lower-than-liquidation-cratio'
      );
      collateralTypes[_collateralType].liquidationCRatio = _data;
    } else {
      revert('OracleRelayer/modify-unrecognized-param');
    }
    emit ModifyParameters(_collateralType, _parameter, _data);
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
   * @param  _collateralType The collateral we want to update prices (safety and liquidation prices) for
   */
  function updateCollateralPrice(bytes32 _collateralType) external {
    (uint256 _priceFeedValue, bool _hasValidValue) = collateralTypes[_collateralType].orcl.getResultWithValidity();
    uint256 _updatedRedemptionPrice = _getRedemptionPrice();

    uint256 _safetyPrice = _hasValidValue
      ? (uint256(_priceFeedValue) * uint256(10 ** 9)).rdiv(_updatedRedemptionPrice).rdiv(
        collateralTypes[_collateralType].safetyCRatio
      )
      : 0;
    uint256 _liquidationPrice = _hasValidValue
      ? (uint256(_priceFeedValue) * uint256(10 ** 9)).rdiv(_updatedRedemptionPrice).rdiv(
        collateralTypes[_collateralType].liquidationCRatio
      )
      : 0;
    safeEngine.modifyParameters(_collateralType, 'safetyPrice', abi.encode(_safetyPrice));
    safeEngine.modifyParameters(_collateralType, 'liquidationPrice', abi.encode(_liquidationPrice));
    emit UpdateCollateralPrice(_collateralType, _priceFeedValue, _safetyPrice, _liquidationPrice);
  }

  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */
  function disableContract() external isAuthorized whenEnabled {
    _disableContract();
    redemptionRate = RAY;
  }

  /**
   * @notice Fetch the safety CRatio of a specific collateral type
   * @param  _collateralType The collateral type we want the safety CRatio for
   */
  function safetyCRatio(bytes32 _collateralType) external view returns (uint256 _safetyCRatio) {
    _safetyCRatio = collateralTypes[_collateralType].safetyCRatio;
  }

  /**
   * @notice Fetch the liquidation CRatio of a specific collateral type
   * @param collateralType The collateral type we want the liquidation CRatio for
   */
  function liquidationCRatio(bytes32 collateralType) external view returns (uint256 _liquidationCRatio) {
    _liquidationCRatio = collateralTypes[collateralType].liquidationCRatio;
  }

  /**
   * @notice Fetch the oracle price feed of a specific collateral type
   * @param  _collateralType The collateral type we want the oracle price feed for
   */
  function orcl(bytes32 _collateralType) external view returns (address _orcl) {
    _orcl = address(collateralTypes[_collateralType].orcl);
  }
}
