// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ILiquidationEngine is IAuthorizable, IDisableable, IModifiable, IModifiablePerCollateral {
  // --- Events ---

  /**
   * @notice Emitted when a SAFE saviour contract is added to the allowlist
   * @param  _saviour SAFE saviour contract being allowlisted
   */
  event ConnectSAFESaviour(address _saviour);

  /**
   * @notice Emitted when a SAFE saviour contract is removed from the allowlist
   * @param  _saviour SAFE saviour contract being removed from the allowlist
   */
  event DisconnectSAFESaviour(address _saviour);

  /**
   * @notice Emitted when the current on auction system coins counter is updated
   * @param  _currentOnAuctionSystemCoins New value of the current on auction system coins counter
   */
  event UpdateCurrentOnAuctionSystemCoins(uint256 _currentOnAuctionSystemCoins);

  /**
   * @notice Emitted when a SAFE is liquidated
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safe Address of the SAFE being liquidated
   * @param  _collateralAmount Amount of collateral being confiscated [wad]
   * @param  _debtAmount Amount of debt being transferred [wad]
   * @param  _amountToRaise Amount of system coins to raise in the collateral auction [rad]
   * @param  _collateralAuctioneer Address of the collateral auctioneer contract handling the collateral auction
   * @param  _auctionId Id of the collateral auction
   */
  event Liquidate(
    bytes32 indexed _cType,
    address indexed _safe,
    uint256 _collateralAmount,
    uint256 _debtAmount,
    uint256 _amountToRaise,
    address _collateralAuctioneer,
    uint256 _auctionId
  );

  /**
   * @notice Emitted when a SAFE is saved from being liquidated by a SAFE saviour contract
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safe Address of the SAFE being saved
   * @param  _collateralAddedOrDebtRepaid Amount of collateral being added or debt repaid [wad]
   */
  event SaveSAFE(bytes32 indexed _cType, address indexed _safe, uint256 _collateralAddedOrDebtRepaid);

  /**
   * @notice Emitted when a SAFE saviour action is unsuccessful
   * @param  _failReason Reason why the SAFE saviour action failed
   */
  event FailedSAFESave(bytes _failReason);

  /**
   * @notice Emitted when a SAFE saviour contract is chosen for a SAFE
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safe Address of the SAFE being saved
   * @param  _saviour Address of the SAFE saviour contract chosen
   */
  event ProtectSAFE(bytes32 indexed _cType, address indexed _safe, address _saviour);

  // --- Errors ---

  /// @notice Throws when trying to add a reverting SAFE saviour to the allowlist
  error LiqEng_SaviourNotOk();
  /// @notice Throws when trying to add an invalid SAFE saviour to the allowlist
  error LiqEng_InvalidAmounts();
  /// @notice Throws when trying to choose a SAFE saviour for a SAFE without the proper authorization
  error LiqEng_CannotModifySAFE();
  /// @notice Throws when trying to choose a SAFE saviour that is not on the allowlist
  error LiqEng_SaviourNotAuthorized();
  /// @notice Throws when trying to liquidate a SAFE that is not unsafe
  error LiqEng_SAFENotUnsafe();
  /// @notice Throws when trying to simultaneously liquidate more debt than the limit allows
  error LiqEng_LiquidationLimitHit();
  /// @notice Throws when SAFE saviour action is invalid during a liquidation
  error LiqEng_InvalidSAFESaviourOperation();
  /// @notice Throws when trying to liquidate a SAFE with a null amount of debt
  error LiqEng_NullAuction();
  /// @notice Throws when trying to liquidate a SAFE with a null amount of collateral to sell
  error LiqEng_NullCollateralToSell();
  /// @notice Throws when trying to call a function only the liquidator is allowed to call
  error LiqEng_OnlyLiqEng();

  // --- Structs ---

  struct LiquidationEngineParams {
    // Max amount of system coins to be auctioned at the same time
    uint256 /* RAD */ onAuctionSystemCoinLimit;
    // The gas limit for the saviour call
    uint256 /*       */ saviourGasLimit;
  }

  struct LiquidationEngineCollateralParams {
    // Address of the collateral auction house handling liquidations for this collateral type
    address /*       */ collateralAuctionHouse;
    // Penalty applied to every liquidation involving this collateral type
    uint256 /* WAD % */ liquidationPenalty;
    // Max amount of system coins to request in one auction for this collateral type
    uint256 /* RAD   */ liquidationQuantity;
  }

  // --- Registry ---

  /**
   * @notice The SAFEEngine is used to query the state of the SAFEs, confiscate the collateral and transfer the debt
   * @return _safeEngine Address of the contract that handles the state of the SAFEs
   */
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  /**
   * @notice The AccountingEngine is used to push the debt into the system, and set as the first bidder on the collateral auctions
   * @return _accountingEngine Address of the AccountingEngine
   */
  function accountingEngine() external view returns (IAccountingEngine _accountingEngine);

  // --- Params ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _liqEngineParams LiquidationEngine parameters struct
   */
  function params() external view returns (LiquidationEngineParams memory _liqEngineParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _onAuctionSystemCoinLimit Max amount of system coins to be auctioned at the same time [rad]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _onAuctionSystemCoinLimit, uint256 _saviourGasLimit);

  /**
   * @notice Getter for the collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _liqEngineCParams LiquidationEngine collateral parameters struct
   */
  function cParams(bytes32 _cType) external view returns (LiquidationEngineCollateralParams memory _liqEngineCParams);

  /**
   * @notice Getter for the unpacked collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _collateralAuctionHouse Address of the collateral auction house handling liquidations
   * @return _liquidationPenalty Penalty applied to every liquidation involving this collateral type [wad%]
   * @return _liquidationQuantity Max amount of system coins to request in one auction for this collateral type [rad]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (address _collateralAuctionHouse, uint256 _liquidationPenalty, uint256 _liquidationQuantity);

  // --- Data ---

  /**
   * @notice The limit adjusted debt to cover
   * @param  _cType The SAFE's collateral type
   * @param  _safe The SAFE's address
   * @return _wad The limit adjusted debt to cover
   */
  function getLimitAdjustedDebtToCover(bytes32 _cType, address _safe) external view returns (uint256 _wad);

  /// @notice Total amount of system coins currently being auctioned
  function currentOnAuctionSystemCoins() external view returns (uint256 _currentOnAuctionSystemCoins);

  // --- SAFE Saviours ---

  /**
   * @notice Allowed contracts that can be chosen to save SAFEs from liquidation
   * @param  _saviour The SAFE saviour contract to check
   * @return _canSave Whether the contract can save SAFEs or not
   */
  function safeSaviours(address _saviour) external view returns (bool _canSave);

  /**
   * @notice Saviour contract chosen for each SAFE by its owner
   * @param  _cType The SAFE's collateral type
   * @param  _safe The SAFE's address
   * @return _saviour The SAFE's saviour contract (address(0) if none)
   */
  function chosenSAFESaviour(bytes32 _cType, address _safe) external view returns (address _saviour);

  // --- Methods ---

  /**
   * @notice Remove debt that was being auctioned
   * @dev    Usually called by CollateralAuctionHouse when an auction is settled
   * @param  _rad The amount of debt in RAD to withdraw from `currentOnAuctionSystemCoins`
   */
  function removeCoinsFromAuction(uint256 _rad) external;

  /**
   * @notice Liquidate a SAFE
   * @dev    A SAFE can be liquidated if the accumulated debt plus the liquidation penalty is higher than the collateral value
   * @param  _cType The SAFE's collateral type
   * @param  _safe The SAFE's address
   * @return _auctionId The auction id of the collateral auction
   */
  function liquidateSAFE(bytes32 _cType, address _safe) external returns (uint256 _auctionId);

  /**
   * @notice Choose a saviour contract for your SAFE
   * @param  _cType The SAFE's collateral type
   * @param  _safe The SAFE's address
   * @param  _saviour The chosen saviour
   */
  function protectSAFE(bytes32 _cType, address _safe, address _saviour) external;

  // --- Administration ---

  /**
   * @notice Authed function to add contracts that can save SAFEs from liquidation
   * @param  _saviour SAFE saviour contract to be whitelisted
   */
  function connectSAFESaviour(address _saviour) external;

  /**
   * @notice Authed function to remove contracts that can save SAFEs from liquidation
   * @param  _saviour SAFE saviour contract to be removed
   */
  function disconnectSAFESaviour(address _saviour) external;
}
