// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IModifiablePerCollateral, GLOBAL_PARAM} from '@interfaces/utils/IModifiablePerCollateral.sol';

interface ILiquidationEngine is IAuthorizable, IDisableable, IModifiablePerCollateral {
  // --- Params ---
  struct LiquidationEngineParams {
    IAccountingEngine accountingEngine;
    uint256 onAuctionSystemCoinLimit;
  }

  struct LiquidationEngineCollateralParams {
    address collateralAuctionHouse;
    uint256 liquidationPenalty;
    uint256 liquidationQuantity;
  }

  // --- Events ---
  event ConnectSAFESaviour(address _saviour);
  event DisconnectSAFESaviour(address _saviour);
  event UpdateCurrentOnAuctionSystemCoins(uint256 _currentOnAuctionSystemCoins);
  event Liquidate(
    bytes32 indexed _collateralType,
    address indexed _safe,
    uint256 _collateralAmount,
    uint256 _debtAmount,
    uint256 _amountToRaise,
    address _collateralAuctioneer,
    uint256 _auctionId
  );
  event SaveSAFE(bytes32 indexed _collateralType, address indexed _safe, uint256 _collateralAddedOrDebtRepaid);
  event FailedSAFESave(bytes _failReason);
  event ProtectSAFE(bytes32 indexed _collateralType, address indexed _safe, address _saviour);

  // --- Structs ---
  struct CollateralType {
    // Address of the collateral auction house handling liquidations for this collateral type
    address collateralAuctionHouse;
    // Penalty applied to every liquidation involving this collateral type. Discourages SAFE users from bidding on their own SAFEs
    uint256 liquidationPenalty; // [wad]
    // Max amount of system coins to request in one auction
    uint256 liquidationQuantity; // [rad]
  }

  function removeCoinsFromAuction(uint256 _rad) external;
  function params() external view returns (IAccountingEngine _accountingEngine, uint256 _onAuctionSystemCoinLimit);
  function cParams(bytes32 _collateralType)
    external
    view
    returns (
      address _collateralAuctionHouse,
      uint256 /* wad */ _liquidationPenalty,
      uint256 /* rad */ _liquidationQuantity
    );

  function connectSAFESaviour(address _saviour) external;
  function disconnectSAFESaviour(address _saviour) external;
  function protectSAFE(bytes32 _collateralType, address _safe, address _saviour) external;
  function liquidateSAFE(bytes32 _collateralType, address _safe) external returns (uint256 _auctionId);
  function getLimitAdjustedDebtToCover(bytes32 _collateralType, address _safe) external view returns (uint256 _wad);
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function currentOnAuctionSystemCoins() external view returns (uint256 _currentOnAuctionSystemCoins);
  function safeSaviours(address _saviour) external view returns (uint256 _canSave);
  function chosenSAFESaviour(bytes32 _collateralType, address _safe) external view returns (address _saviour);
  function mutex(bytes32 _collateralType, address _safe) external view returns (uint8 _mutex);
}
