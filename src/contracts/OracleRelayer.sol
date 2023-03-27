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

import {ISAFEEngine as SAFEEngineLike} from '../interfaces/ISAFEEngine.sol';
import {IOracle as OracleLike} from '../interfaces/IOracle.sol';

import {Math, RAY, WAD} from './utils/Math.sol';

contract OracleRelayer {
  using Math for uint256;

  // --- Auth ---
  mapping(address => uint256) public authorizedAccounts;
  /**
   * @notice Add auth to an account
   * @param account Account to add auth to
   */

  function addAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 1;
    emit AddAuthorization(account);
  }
  /**
   * @notice Remove auth from an account
   * @param account Account to remove auth from
   */

  function removeAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 0;
    emit RemoveAuthorization(account);
  }
  /**
   * @notice Checks whether msg.sender can call an authed function
   *
   */

  modifier isAuthorized() {
    require(authorizedAccounts[msg.sender] == 1, 'OracleRelayer/account-not-authorized');
    _;
  }

  // --- Data ---
  struct CollateralType {
    // Usually an oracle security module that enforces delays to fresh price feeds
    OracleLike orcl;
    // CRatio used to compute the 'safePrice' - the price used when generating debt in SAFEEngine
    uint256 safetyCRatio;
    // CRatio used to compute the 'liquidationPrice' - the price used when liquidating SAFEs
    uint256 liquidationCRatio;
  }

  // Data about each collateral type
  mapping(bytes32 => CollateralType) public collateralTypes;

  SAFEEngineLike public safeEngine;

  // Whether this contract is enabled
  uint256 public contractEnabled;
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

  // --- Events ---
  event AddAuthorization(address account);
  event RemoveAuthorization(address account);
  event DisableContract();
  event ModifyParameters(bytes32 collateralType, bytes32 parameter, address addr);
  event ModifyParameters(bytes32 parameter, uint256 data);
  event ModifyParameters(bytes32 collateralType, bytes32 parameter, uint256 data);
  event UpdateRedemptionPrice(uint256 redemptionPrice);
  event UpdateCollateralPrice(
    bytes32 indexed collateralType, uint256 priceFeedValue, uint256 safetyPrice, uint256 liquidationPrice
  );

  // --- Init ---
  constructor(address _safeEngine) {
    authorizedAccounts[msg.sender] = 1;

    safeEngine = SAFEEngineLike(_safeEngine);
    _redemptionPrice = RAY;
    redemptionRate = RAY;
    redemptionPriceUpdateTime = block.timestamp;
    redemptionRateUpperBound = RAY * WAD;
    redemptionRateLowerBound = 1;
    contractEnabled = 1;

    emit AddAuthorization(msg.sender);
  }

  // --- Administration ---
  /**
   * @notice Modify oracle price feed addresses
   * @param collateralType Collateral whose oracle we change
   * @param parameter Name of the parameter
   * @param addr New oracle address
   */
  function modifyParameters(bytes32 collateralType, bytes32 parameter, address addr) external isAuthorized {
    require(contractEnabled == 1, 'OracleRelayer/contract-not-enabled');
    if (parameter == 'orcl') collateralTypes[collateralType].orcl = OracleLike(addr);
    else revert('OracleRelayer/modify-unrecognized-param');
    emit ModifyParameters(collateralType, parameter, addr);
  }
  /**
   * @notice Modify redemption rate/price related parameters
   * @param parameter Name of the parameter
   * @param data New param value
   */

  function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
    require(contractEnabled == 1, 'OracleRelayer/contract-not-enabled');
    require(data > 0, 'OracleRelayer/null-data');
    if (parameter == 'redemptionPrice') {
      _redemptionPrice = data;
    } else if (parameter == 'redemptionRate') {
      require(block.timestamp == redemptionPriceUpdateTime, 'OracleRelayer/redemption-price-not-updated');
      uint256 adjustedRate = data;
      if (data > redemptionRateUpperBound) {
        adjustedRate = redemptionRateUpperBound;
      } else if (data < redemptionRateLowerBound) {
        adjustedRate = redemptionRateLowerBound;
      }
      redemptionRate = adjustedRate;
    } else if (parameter == 'redemptionRateUpperBound') {
      require(data > RAY, 'OracleRelayer/invalid-redemption-rate-upper-bound');
      redemptionRateUpperBound = data;
    } else if (parameter == 'redemptionRateLowerBound') {
      require(data < RAY, 'OracleRelayer/invalid-redemption-rate-lower-bound');
      redemptionRateLowerBound = data;
    } else {
      revert('OracleRelayer/modify-unrecognized-param');
    }
    emit ModifyParameters(parameter, data);
  }
  /**
   * @notice Modify CRatio related parameters
   * @param collateralType Collateral whose parameters we change
   * @param parameter Name of the parameter
   * @param data New param value
   */

  function modifyParameters(bytes32 collateralType, bytes32 parameter, uint256 data) external isAuthorized {
    require(contractEnabled == 1, 'OracleRelayer/contract-not-enabled');
    if (parameter == 'safetyCRatio') {
      require(
        data >= collateralTypes[collateralType].liquidationCRatio, 'OracleRelayer/safety-lower-than-liquidation-cratio'
      );
      collateralTypes[collateralType].safetyCRatio = data;
    } else if (parameter == 'liquidationCRatio') {
      require(
        data <= collateralTypes[collateralType].safetyCRatio, 'OracleRelayer/safety-lower-than-liquidation-cratio'
      );
      collateralTypes[collateralType].liquidationCRatio = data;
    } else {
      revert('OracleRelayer/modify-unrecognized-param');
    }
    emit ModifyParameters(collateralType, parameter, data);
  }

  // --- Redemption Price Update ---
  /**
   * @notice Update the redemption price using the current redemption rate
   */
  function updateRedemptionPrice() internal returns (uint256) {
    // Update redemption price
    _redemptionPrice = redemptionRate.rpow(block.timestamp - redemptionPriceUpdateTime).rmul(_redemptionPrice);
    if (_redemptionPrice == 0) _redemptionPrice = 1;
    redemptionPriceUpdateTime = block.timestamp;
    emit UpdateRedemptionPrice(_redemptionPrice);
    // Return updated redemption price
    return _redemptionPrice;
  }
  /**
   * @notice Fetch the latest redemption price by first updating it
   */

  function redemptionPrice() public returns (uint256) {
    if (block.timestamp > redemptionPriceUpdateTime) return updateRedemptionPrice();
    return _redemptionPrice;
  }

  // --- Update value ---
  /**
   * @notice Update the collateral price inside the system (inside SAFEEngine)
   * @param collateralType The collateral we want to update prices (safety and liquidation prices) for
   */
  function updateCollateralPrice(bytes32 collateralType) external {
    (uint256 priceFeedValue, bool hasValidValue) = collateralTypes[collateralType].orcl.getResultWithValidity();
    uint256 redemptionPrice_ = redemptionPrice();
    uint256 safetyPrice_ = hasValidValue
      ? (uint256(priceFeedValue) * uint256(10 ** 9)).rdiv(redemptionPrice_).rdiv(
        collateralTypes[collateralType].safetyCRatio
      )
      : 0;
    uint256 liquidationPrice_ = hasValidValue
      ? (uint256(priceFeedValue) * uint256(10 ** 9)).rdiv(redemptionPrice_).rdiv(
        collateralTypes[collateralType].liquidationCRatio
      )
      : 0;

    safeEngine.modifyParameters(collateralType, 'safetyPrice', safetyPrice_);
    safeEngine.modifyParameters(collateralType, 'liquidationPrice', liquidationPrice_);
    emit UpdateCollateralPrice(collateralType, priceFeedValue, safetyPrice_, liquidationPrice_);
  }

  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */
  function disableContract() external isAuthorized {
    contractEnabled = 0;
    redemptionRate = RAY;
    emit DisableContract();
  }

  /**
   * @notice Fetch the safety CRatio of a specific collateral type
   * @param collateralType The collateral type we want the safety CRatio for
   */
  function safetyCRatio(bytes32 collateralType) public view returns (uint256) {
    return collateralTypes[collateralType].safetyCRatio;
  }
  /**
   * @notice Fetch the liquidation CRatio of a specific collateral type
   * @param collateralType The collateral type we want the liquidation CRatio for
   */

  function liquidationCRatio(bytes32 collateralType) public view returns (uint256) {
    return collateralTypes[collateralType].liquidationCRatio;
  }
  /**
   * @notice Fetch the oracle price feed of a specific collateral type
   * @param collateralType The collateral type we want the oracle price feed for
   */

  function orcl(bytes32 collateralType) public view returns (address) {
    return address(collateralTypes[collateralType].orcl);
  }
}
