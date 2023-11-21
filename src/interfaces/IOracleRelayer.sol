// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface IOracleRelayer is IAuthorizable, IDisableable, IModifiable, IModifiablePerCollateral {
  // --- Events ---

  /**
   * @notice Emitted when the redemption price is updated
   * @param _redemptionPrice The new redemption price [ray]
   */
  event UpdateRedemptionPrice(uint256 _redemptionPrice);

  /**
   * @notice Emitted when a collateral type price is updated
   * @param _cType Bytes32 representation of the collateral type
   * @param _priceFeedValue The new collateral price [wad]
   * @param _safetyPrice The new safety price [ray]
   * @param _liquidationPrice The new liquidation price [ray]
   */
  event UpdateCollateralPrice(
    bytes32 indexed _cType, uint256 _priceFeedValue, uint256 _safetyPrice, uint256 _liquidationPrice
  );

  // --- Errors ---

  /// @notice Throws if the redemption price is not updated when updating the rate
  error OracleRelayer_RedemptionPriceNotUpdated();
  /// @notice Throws when trying to initialize a collateral type that is already initialized
  error OracleRelayer_CollateralTypeAlreadyInitialized();

  // --- Structs ---

  struct OracleRelayerParams {
    // Upper bound for the per-second redemption rate
    uint256 /* RAY */ redemptionRateUpperBound;
    // Lower bound for the per-second redemption rate
    uint256 /* RAY */ redemptionRateLowerBound;
  }

  struct OracleRelayerCollateralParams {
    // Usually a DelayedOracle that enforces delays to fresh price feeds
    IBaseOracle /* */ oracle;
    // CRatio used to compute the 'safePrice' - the price used when generating debt in SAFEEngine
    uint256 /* RAY    */ safetyCRatio;
    // CRatio used to compute the 'liquidationPrice' - the price used when liquidating SAFEs
    uint256 /* RAY    */ liquidationCRatio;
  }

  // --- Registry ---

  /**
   * @notice The SAFEEngine is called to update the price of the collateral in the system
   * @return _safeEngine Address of the contract that handles the state of the SAFEs
   */
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  /**
   * @notice The oracle used to fetch the system coin market price
   * @return _systemCoinOracle Address of the contract that provides the system coin price
   */
  function systemCoinOracle() external view returns (IBaseOracle _systemCoinOracle);

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _oracleRelayerParams An OracleRelayerParams struct
   */
  function params() external view returns (OracleRelayerParams memory _oracleRelayerParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _redemptionRateUpperBound Upper bound for the per-second redemption rate [ray]
   * @return _redemptionRateLowerBound Lower bound for the per-second redemption rate [ray]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _redemptionRateUpperBound, uint256 _redemptionRateLowerBound);

  /**
   * @notice Getter for the collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _oracleRelayerCParams An OracleRelayerCollateralParams struct
   */
  function cParams(bytes32 _cType) external view returns (OracleRelayerCollateralParams memory _oracleRelayerCParams);

  /**
   * @notice Getter for the unpacked collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return  _oracle Usually a DelayedOracle that enforces delays to fresh price feeds
   * @return  _safetyCRatio CRatio used to compute the 'safePrice' - the price used when generating debt in SAFEEngine [ray]
   * @return  _liquidationCRatio CRatio used to compute the 'liquidationPrice' - the price used when liquidating SAFEs [ray]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (IBaseOracle _oracle, uint256 _safetyCRatio, uint256 _liquidationCRatio);

  // --- Data ---

  /**
   * @notice View method to fetch the current redemption price
   * @return _redemptionPrice The current calculated redemption price [ray]
   */
  function calcRedemptionPrice() external view returns (uint256 _redemptionPrice);

  /**
   * @notice The current system coin market price
   * @return _marketPrice The current system coin market price [ray]
   */
  function marketPrice() external view returns (uint256 _marketPrice);

  /**
   * @notice The redemption rate is the rate at which the redemption price changes over time
   * @return _redemptionRate The current updated redemption rate [ray]
   * @dev    By changing the redemption rate, it changes the incentives of the system users
   * @dev    The redemption rate is a per-second rate [ray]
   */
  function redemptionRate() external view returns (uint256 _redemptionRate);

  /**
   * @notice Last time when the redemption price was changed
   * @return _redemptionPriceUpdateTime The last time when the redemption price was changed [unix timestamp]
   * @dev    Used to calculate the current redemption price
   */
  function redemptionPriceUpdateTime() external view returns (uint256 _redemptionPriceUpdateTime);

  // --- Methods ---

  /**
   * @notice Fetch the latest redemption price by first updating it
   * @return _updatedPrice The newly updated redemption price [ray]
   */
  function redemptionPrice() external returns (uint256 _updatedPrice);

  /**
   * @notice Update the collateral price inside the system (inside SAFEEngine)
   * @dev    Usually called by a keeper, incentivized by the system to keep the prices up to date
   * @param  _cType Bytes32 representation of the collateral type
   */
  function updateCollateralPrice(bytes32 _cType) external;

  /**
   * @notice Update the system redemption rate, the rate at which the redemption price changes over time
   * @dev    Usually called by the PIDRateSetter
   * @param  _redemptionRate The newly calculated redemption rate [ray]
   */
  function updateRedemptionRate(uint256 _redemptionRate) external;
}
