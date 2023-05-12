// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine as LiquidationEngineLike} from '@interfaces/ILiquidationEngine.sol';
import {IAccountingEngine as AccountingEngineLike} from '@interfaces/IAccountingEngine.sol';
import {IOracleRelayer as OracleRelayerLike} from '@interfaces/IOracleRelayer.sol';
import {IDisableable as CoinSavingsAccountLike} from '@interfaces/utils/IDisableable.sol';
import {IStabilityFeeTreasury as StabilityFeeTreasuryLike} from '@interfaces/IStabilityFeeTreasury.sol';
import {ICollateralAuctionHouse as CollateralAuctionHouseLike} from '@interfaces/ICollateralAuctionHouse.sol';
import {IOracle as OracleLike} from '@interfaces/IOracle.sol';

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
  function safeEngine() external view returns (SAFEEngineLike _safeEngine);
  function liquidationEngine() external view returns (LiquidationEngineLike _liquidationEngine);
  function accountingEngine() external view returns (AccountingEngineLike _accountingEngine);
  function oracleRelayer() external view returns (OracleRelayerLike _oracleRelayer);
  function coinSavingsAccount() external view returns (CoinSavingsAccountLike _coinSavingsAccount);
  function stabilityFeeTreasury() external view returns (StabilityFeeTreasuryLike _stabilityFeeTreasury);

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
