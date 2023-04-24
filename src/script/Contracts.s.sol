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
import {GlobalSettlement} from '@contracts/settlement/GlobalSettlement.sol';
// TODO: import {ESM} from "@contracts/ESM.sol";
import {StabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {OracleRelayer} from '@contracts/OracleRelayer.sol';
import {PIDController} from '@contracts/PIDController.sol';
import {PIDRateSetter} from '@contracts/PIDRateSetter.sol';

import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';

import {ERC20ForTest, ERC20, IERC20} from '@contracts/for-test/ERC20ForTest.sol';

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

  MixedStratSurplusAuctionHouse public surplusAuctionHouse;
  DebtAuctionHouse public debtAuctionHouse;

  mapping(bytes32 => ERC20ForTest) public collateral;
  mapping(bytes32 => CollateralJoin) public collateralJoin;
  mapping(bytes32 => CollateralAuctionHouse) public collateralAuctionHouse;

  OracleRelayer public oracleRelayer;
  mapping(bytes32 => OracleForTest) public oracle;

  PIDController public pidController;
  PIDRateSetter public pidRateSetter;

  GlobalSettlement public globalSettlement;
  // ESM public esm;
}
