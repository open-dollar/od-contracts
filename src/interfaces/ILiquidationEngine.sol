// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ILiquidationEngine is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---
  event ConnectSAFESaviour(address _saviour);
  event DisconnectSAFESaviour(address _saviour);
  event UpdateCurrentOnAuctionSystemCoins(uint256 _currentOnAuctionSystemCoins);
  event Liquidate(
    bytes32 indexed _cType,
    address indexed _safe,
    uint256 _collateralAmount,
    uint256 _debtAmount,
    uint256 _amountToRaise,
    address _collateralAuctioneer,
    uint256 _auctionId
  );
  event SaveSAFE(bytes32 indexed _cType, address indexed _safe, uint256 _collateralAddedOrDebtRepaid);
  event FailedSAFESave(bytes _failReason);
  event ProtectSAFE(bytes32 indexed _cType, address indexed _safe, address _saviour);

  // --- Errors ---
  error LiqEng_SaviourNotOk();
  error LiqEng_InvalidAmounts();
  error LiqEng_CannotModifySAFE();
  error LiqEng_SaviourNotAuthorized();
  error LiqEng_SAFENotUnsafe();
  error LiqEng_LiquidationLimitHit();
  error LiqEng_InvalidSAFESaviourOperation();
  error LiqEng_NullAuction();
  error LiqEng_DustySAFE();
  error LiqEng_NullCollateralToSell();
  error LiqEng_CollateralTypeAlreadyInitialized();

  // --- Structs ---
  struct LiquidationEngineParams {
    uint256 onAuctionSystemCoinLimit;
  }

  struct LiquidationEngineCollateralParams {
    address collateralAuctionHouse;
    uint256 liquidationPenalty;
    uint256 liquidationQuantity;
  }

  // --- Registry ---
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function accountingEngine() external view returns (IAccountingEngine _accountingEngine);

  // --- Params ---
  function params() external view returns (LiquidationEngineParams memory _liqEngineParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _onAuctionSystemCoinLimit);

  function cParams(bytes32 _cType) external view returns (LiquidationEngineCollateralParams memory _liqEngineCParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (address _collateralAuctionHouse, uint256 _liquidationPenalty, uint256 _liquidationQuantity);

  // --- Data ---
  function getLimitAdjustedDebtToCover(bytes32 _cType, address _safe) external view returns (uint256 _wad);
  function currentOnAuctionSystemCoins() external view returns (uint256 _currentOnAuctionSystemCoins);
  function safeSaviours(address _saviour) external view returns (uint256 _canSave);
  function chosenSAFESaviour(bytes32 _cType, address _safe) external view returns (address _saviour);

  // --- Methods ---
  function removeCoinsFromAuction(uint256 _rad) external;
  function connectSAFESaviour(address _saviour) external;
  function disconnectSAFESaviour(address _saviour) external;
  function protectSAFE(bytes32 _cType, address _safe, address _saviour) external;
  function liquidateSAFE(bytes32 _cType, address _safe) external returns (uint256 _auctionId);
  function initializeCollateralType(
    bytes32 _cType,
    LiquidationEngineCollateralParams memory _collateralParams
  ) external;

  // --- Views ---
  function collateralList() external view returns (bytes32[] memory __collateralList);
}
