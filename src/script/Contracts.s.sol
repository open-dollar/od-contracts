// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {ETHJoin} from '@contracts/utils/ETHJoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {MixedStratSurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';
import {DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {IncreasingDiscountCollateralAuctionHouse as CollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {Coin} from '@contracts/utils/Coin.sol';
import {GlobalSettlement} from '@contracts/GlobalSettlement.sol';
// TODO: import {ESM} from "@contracts/ESM.sol";
import {StabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {OracleRelayer} from '@contracts/OracleRelayer.sol';

import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';

contract Contracts {
  SAFEEngine public safeEngine;
  TaxCollector public taxCollector;
  AccountingEngine public accountingEngine;
  LiquidationEngine public liquidationEngine;
  StabilityFeeTreasury public stabilityFeeTreasury;

  Coin public coin;
  Coin public protocolToken;
  CoinJoin public coinJoin;
  ETHJoin public ethJoin;
  Coin public collateral;
  CollateralJoin public collateralJoin;

  MixedStratSurplusAuctionHouse public surplusAuctionHouse;
  DebtAuctionHouse public debtAuctionHouse;

  CollateralAuctionHouse public ethCollateralAuctionHouse;
  CollateralAuctionHouse public collateralAuctionHouse;

  OracleRelayer public oracleRelayer;
  OracleForTest public ethOracle;
  OracleForTest public collateralOracle;

  GlobalSettlement public globalSettlement;
  // ESM public esm;
}
