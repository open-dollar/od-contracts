// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IGlobalSettlement is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---

  /// @notice Emitted when the system is shutdown and the global settlement process begins
  event ShutdownSystem();

  /**
   * @notice Emitted when a collateral type's final price is calculated
   * @param _cType Bytes32 representation of the collateral type
   * @param _finalCoinPerCollateralPrice The final amount of collateral that a system coin can redeem [rad]
   */
  event FreezeCollateralType(bytes32 indexed _cType, uint256 _finalCoinPerCollateralPrice);

  /**
   * @notice Emitted when a collateral auction is fast tracked
   * @param _cType Bytes32 representation of the collateral type
   * @param _auctionId The ID of the auction to be fast tracked
   * @param _collateralTotalDebt The cumulative amount of debt for the collateral type [wad]
   */
  event FastTrackAuction(bytes32 indexed _cType, uint256 indexed _auctionId, uint256 _collateralTotalDebt);

  /**
   * @notice Emitted when a SAFE is processed
   * @param _cType Bytes32 representation of the collateral type
   * @param _safe Address of the processed SAFE
   * @param _collateralShortfall The cumulative amount of bad debt for the collateral type [wad]
   */
  event ProcessSAFE(bytes32 indexed _cType, address indexed _safe, uint256 _collateralShortfall);

  /**
   * @notice Emitted when a SAFE's surplus collateral is withdrawn
   * @param _cType Bytes32 representation of the collateral type
   * @param _sender Address of the caller (representing the SAFE)
   * @param _collateralAmount The amount of collateral withdrawn [wad]
   */
  event FreeCollateral(bytes32 indexed _cType, address indexed _sender, uint256 _collateralAmount);

  /**
   * @notice Emitted when the final outstanding coin supply is set
   * @param _outstandingCoinSupply The final outstanding coin supply [rad]
   */
  event SetOutstandingCoinSupply(uint256 _outstandingCoinSupply);

  /**
   * @notice Emitted when a collateral type's cash price is calculated
   * @param _cType Bytes32 representation of the collateral type
   * @param _collateralCashPrice The final collateral cash price [ray]
   */
  event CalculateCashPrice(bytes32 indexed _cType, uint256 _collateralCashPrice);

  /**
   * @notice Emitted when a user adds coins into a 'bag' so that they can use them to redeem collateral
   * @param _sender Address of the caller
   * @param _coinBag The cumulative of coins prepared for redeeming [wad]
   */
  event PrepareCoinsForRedeeming(address indexed _sender, uint256 _coinBag);

  /**
   * @notice Emitted when a user redeems a specific collateral type using an amount of internal system coins from their bag
   * @param _cType Bytes32 representation of the collateral type
   * @param _sender Address of the caller
   * @param _coinsAmount The amount of internal coins used from the bag [wad]
   * @param _collateralAmount The amount of collateral redeemed [wad]
   */
  event RedeemCollateral(
    bytes32 indexed _cType, address indexed _sender, uint256 _coinsAmount, uint256 _collateralAmount
  );

  // --- Errors ---
  /// @notice Throws when trying to freeze a collateral type that has already been frozen
  error GS_FinalCollateralPriceAlreadyDefined();
  /// @notice Throws when trying to fast track an auction while the collateral type is not frozen
  error GS_FinalCollateralPriceNotDefined();
  /// @notice Throws when trying to free the collateral from an unprocessed SAFE
  error GS_SafeDebtNotZero();
  /// @notice Throws when trying to set the final outstanding coin supply, when it was already set
  error GS_OutstandingCoinSupplyNotZero();
  /// @notice Throws when trying to set the final collateral cash price, when the outstanding coin supply was not set
  error GS_OutstandingCoinSupplyZero();
  /// @notice Throws when trying to set the final outstanding coin supply, when there's still surplus in the protocol
  error GS_SurplusNotZero();
  /// @notice Throws when trying to set the final outstanding coin supply, when the cooldown period has not passed
  error GS_ShutdownCooldownNotFinished();
  /// @notice Throws when trying to set the final collateral cash price, when it was already set
  error GS_CollateralCashPriceAlreadyDefined();
  /// @notice Throws when trying to redeem collateral when the final collateral cash price was not set
  error GS_CollateralCashPriceNotDefined();
  /// @notice Throws when trying to redeem more collateral than the user's bag can afford
  error GS_InsufficientBagBalance();

  // --- Structs ---

  struct GlobalSettlementParams {
    // Amount of seconds to wait before calculating the final collateral price after shutdown
    uint256 /* seconds */ shutdownCooldown;
  }

  // --- Data ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _globalSettlementParams GlobalSettlement parameters struct
   */
  function params() external view returns (GlobalSettlementParams memory _globalSettlementParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _shutdownCooldown Amount of seconds to wait before calculating redemptions after shutdown
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _shutdownCooldown);

  /// @notice The timestamp when settlement was triggered
  function shutdownTime() external view returns (uint256 _shutdownTime);

  /// @notice The outstanding coin supply computed during the settlement process [rad]
  function outstandingCoinSupply() external view returns (uint256 _outstandingCoinSupply);

  /**
   * @notice The final coin per collateral price computed during the settlement process
   * @param _cType Bytes32 representation of the collateral type
   * @return _finalCoinPerCollateralPrice The final amount of collateral that a system coin can redeem [rad]
   */
  function finalCoinPerCollateralPrice(bytes32 _cType) external view returns (uint256 _finalCoinPerCollateralPrice);

  /**
   * @notice The total amount of bad debt for a collateral type computed during the settlement process
   * @param _cType Bytes32 representation of the collateral type
   * @return _collateralShortfall The total amount of bad debt for a collateral type [wad]
   */
  function collateralShortfall(bytes32 _cType) external view returns (uint256 _collateralShortfall);

  /**
   * @notice The total amount of debt for a collateral type computed during the settlement process
   * @param _cType Bytes32 representation of the collateral type
   * @return _collateralTotalDebt The total amount of debt for a collateral type [wad]
   */
  function collateralTotalDebt(bytes32 _cType) external view returns (uint256 _collateralTotalDebt);

  /**
   * @notice Final collateral cash price computed during the settlement process, accounting for surplus / shortfall
   * @param _cType Bytes32 representation of the collateral type
   * @return _collateralCashPrice The final collateral cash price [ray]
   */
  function collateralCashPrice(bytes32 _cType) external view returns (uint256 _collateralCashPrice);

  /**
   * @notice Mapping containing the total amount of coins a user has prepared for redeeming
   * @param _coinHolder The address of the user
   * @return _coinBag Amount of coins prepared for redeeming [wad]
   */
  function coinBag(address _coinHolder) external view returns (uint256 _coinBag);

  /**
   * @notice Mapping containing the total amount of coins a user has used to redeem collateral
   * @param _cType Bytes32 representation of the collateral type
   * @param _coinHolder The address of the user
   * @return _coinsUsedToRedeem Amount of coins already used to redeem collateral [wad]
   */
  function coinsUsedToRedeem(bytes32 _cType, address _coinHolder) external view returns (uint256 _coinsUsedToRedeem);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  /// @notice Address of the LiquidationEngine contract
  function liquidationEngine() external view returns (ILiquidationEngine _liquidationEngine);
  /// @notice Address of the OracleRelayer contract
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);

  /// @notice Address of the AccountingEngine contract
  function accountingEngine() external view returns (IDisableable _accountingEngine);
  /// @notice Address of the StabilityFeeTreasury contract
  function stabilityFeeTreasury() external view returns (IDisableable _stabilityFeeTreasury);
  /// @notice Address of the CoinJoin contract
  function coinJoin() external view returns (IDisableable _coinJoin);
  /// @notice Address of the CollateralJoinFactory contract
  function collateralJoinFactory() external view returns (IDisableable _collateralJoinFactory);
  /// @notice Address of the CollateralAuctionHouseFactory contract
  function collateralAuctionHouseFactory() external view returns (IDisableable _collateralAuctionHouseFactory);

  // --- Settlement ---

  /**
   * @notice Freeze the system and start the cooldown period
   * @dev    This function switches the `whenEnabled`/`whenDisabled` modifiers across the system contracts
   */
  function shutdownSystem() external;

  /**
   * @notice Calculate a collateral type's final price according to the latest system coin redemption price
   * @param _cType The collateral type to calculate the price for
   */
  function freezeCollateralType(bytes32 _cType) external;

  /**
   * @notice Fast track an ongoing collateral auction
   * @param _cType The collateral type associated with the auction contract
   * @param _auctionId The ID of the auction to be fast tracked
   */
  function fastTrackAuction(bytes32 _cType, uint256 _auctionId) external;

  /**
   * @notice Cancel a SAFE's debt and leave any extra collateral in it
   * @param _cType The collateral type associated with the SAFE
   * @param _safe The SAFE to be processed
   */
  function processSAFE(bytes32 _cType, address _safe) external;

  /**
   * @notice Remove collateral from the caller's SAFE (requires SAFE to have no debt)
   * @param _cType The collateral type to free
   */
  function freeCollateral(bytes32 _cType) external;

  /**
   * @notice Set the final outstanding supply of system coins
   * @dev There must be no remaining surplus in the accounting engine
   */
  function setOutstandingCoinSupply() external;

  /**
   * @notice Calculate a collateral's price taking into consideration system surplus/deficit and the finalCoinPerCollateralPrice
   * @param _cType The collateral whose cash price will be calculated
   */
  function calculateCashPrice(bytes32 _cType) external;

  /**
   * @notice Add coins into a 'bag' so that you can use them to redeem collateral
   * @param _coinAmount The amount of internal system coins to add into the bag
   */
  function prepareCoinsForRedeeming(uint256 _coinAmount) external;

  /**
   * @notice Redeem a specific collateral type using an amount of internal system coins from your bag
   * @param _cType The collateral type to redeem
   * @param _coinsAmount The amount of internal coins to use from your bag
   */
  function redeemCollateral(bytes32 _cType, uint256 _coinsAmount) external;
}
