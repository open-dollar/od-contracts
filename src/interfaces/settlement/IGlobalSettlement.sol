// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface IGlobalSettlement is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---
  event ShutdownSystem();
  event FreezeCollateralType(bytes32 indexed _cType, uint256 _finalCoinPerCollateralPrice);
  event FastTrackAuction(bytes32 indexed _cType, uint256 indexed _auctionId, uint256 _collateralTotalDebt);
  event ProcessSAFE(bytes32 indexed _cType, address indexed _safe, uint256 _collateralShortfall);
  event FreeCollateral(bytes32 indexed _cType, address indexed _sender, int256 _collateralAmount);
  event SetOutstandingCoinSupply(uint256 _outstandingCoinSupply);
  event CalculateCashPrice(bytes32 indexed _cType, uint256 _collateralCashPrice);
  event PrepareCoinsForRedeeming(address indexed _sender, uint256 _coinBag);
  event RedeemCollateral(
    bytes32 indexed _cType, address indexed _sender, uint256 _coinsAmount, uint256 _collateralAmount
  );

  // --- Errors ---
  error GS_FinalCollateralPriceAlreadyDefined();
  error GS_FinalCollateralPriceNotDefined();
  error GS_SafeDebtNotZero();
  error GS_OutstandingCoinSupplyNotZero();
  error GS_OutstandingCoinSupplyZero();
  error GS_SurplusNotZero();
  error GS_ShutdownCooldownNotFinished();
  error GS_CollateralCashPriceAlreadyDefined();
  error GS_CollateralCashPriceNotDefined();
  error GS_InsufficientBagBalance();

  // --- Data ---
  function shutdownTime() external view returns (uint256 _shutdownTime);
  function shutdownCooldown() external view returns (uint256 _shutdownCooldown);
  function outstandingCoinSupply() external view returns (uint256 _outstandingCoinSupply);

  function finalCoinPerCollateralPrice(bytes32 _cType) external view returns (uint256 _finalCoinPerCollateralPrice);
  function collateralShortfall(bytes32 _cType) external view returns (uint256 _collateralShortfall);
  function collateralTotalDebt(bytes32 _cType) external view returns (uint256 _collateralTotalDebt);
  function collateralCashPrice(bytes32 _cType) external view returns (uint256 _collateralCashPrice);

  function coinBag(address _coinHolder) external view returns (uint256 _coinBag);
  function coinsUsedToRedeem(bytes32 _cType, address _coinHolder) external view returns (uint256 _coinsUsedToRedeem);

  // --- Registry ---
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function liquidationEngine() external view returns (ILiquidationEngine _liquidationEngine);
  function accountingEngine() external view returns (IAccountingEngine _accountingEngine);
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);
  function stabilityFeeTreasury() external view returns (IStabilityFeeTreasury _stabilityFeeTreasury);

  // --- Settlement ---
  function shutdownSystem() external;
  function freezeCollateralType(bytes32 _cType) external;
  function fastTrackAuction(bytes32 _cType, uint256 _auctionId) external;
  function processSAFE(bytes32 _cType, address _safe) external;
  function freeCollateral(bytes32 _cType) external;
  function setOutstandingCoinSupply() external;
  function calculateCashPrice(bytes32 _cType) external;
  function prepareCoinsForRedeeming(uint256 _coinAmount) external;
  function redeemCollateral(bytes32 _cType, uint256 _coinsAmount) external;
}
