// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {TaxCollector, ITaxCollector} from '@contracts/TaxCollector.sol';
import {IAccountingEngine, AccountingEngine} from '@contracts/AccountingEngine.sol';
import {ILiquidationEngine, LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {ETHJoin} from '@contracts/utils/ETHJoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {ISurplusAuctionHouse, SurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';
import {IDebtAuctionHouse, DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {
  IIncreasingDiscountCollateralAuctionHouse,
  IncreasingDiscountCollateralAuctionHouse as CollateralAuctionHouse
} from '@contracts/CollateralAuctionHouse.sol';
import {GlobalSettlement} from '@contracts/settlement/GlobalSettlement.sol';
import {IStabilityFeeTreasury, StabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {PIDController, IPIDController} from '@contracts/PIDController.sol';
import {PIDRateSetter} from '@contracts/PIDRateSetter.sol';

import {IOracleRelayer, OracleRelayer} from '@contracts/OracleRelayer.sol';
import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle} from '@contracts/oracles/DelayedOracle.sol';
import {ChainlinkRelayer} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {CoinForTest as Coin} from '@contracts/for-test/CoinForTest.sol';
import {ERC20ForTest, ERC20, IERC20} from '@contracts/for-test/ERC20ForTest.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';

abstract contract Contracts {
  // --- Base contracts ---
  SAFEEngine public safeEngine;
  TaxCollector public taxCollector;
  AccountingEngine public accountingEngine;
  LiquidationEngine public liquidationEngine;
  StabilityFeeTreasury public stabilityFeeTreasury;
  OracleRelayer public oracleRelayer;
  SurplusAuctionHouse public surplusAuctionHouse;
  DebtAuctionHouse public debtAuctionHouse;
  mapping(bytes32 => CollateralAuctionHouse) public collateralAuctionHouse;

  // --- Token contracts ---
  Coin public protocolToken;
  Coin public coin;
  mapping(bytes32 => ERC20ForTest) public collateral;
  CoinJoin public coinJoin;
  ETHJoin public ethJoin;
  mapping(bytes32 => CollateralJoin) public collateralJoin;

  // --- Oracle contracts ---
  mapping(bytes32 => IBaseOracle) public oracle;

  // --- PID contracts ---
  PIDController public pidController;
  PIDRateSetter public pidRateSetter;

  // --- Settlement contracts ---
  GlobalSettlement public globalSettlement;
}
