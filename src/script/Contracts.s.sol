// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SAFEEngine, ISAFEEngine} from '@contracts/SAFEEngine.sol';
import {TaxCollector, ITaxCollector} from '@contracts/TaxCollector.sol';
import {AccountingEngine, IAccountingEngine} from '@contracts/AccountingEngine.sol';
import {LiquidationEngine, ILiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {CoinJoin, ICoinJoin} from '@contracts/utils/CoinJoin.sol';
import {ETHJoin, IETHJoin} from '@contracts/utils/ETHJoin.sol';
import {CollateralJoin, ICollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {SurplusAuctionHouse, ISurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';
import {DebtAuctionHouse, IDebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {
  IncreasingDiscountCollateralAuctionHouse as CollateralAuctionHouse,
  IIncreasingDiscountCollateralAuctionHouse as ICollateralAuctionHouse
} from '@contracts/CollateralAuctionHouse.sol';
import {GlobalSettlement, IGlobalSettlement} from '@contracts/settlement/GlobalSettlement.sol';
import {StabilityFeeTreasury, IStabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {PIDController, IPIDController} from '@contracts/PIDController.sol';
import {PIDRateSetter, IPIDRateSetter} from '@contracts/PIDRateSetter.sol';

import {OracleRelayer, IOracleRelayer} from '@contracts/OracleRelayer.sol';
import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle} from '@contracts/oracles/DelayedOracle.sol';
import {ChainlinkRelayer} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {ERC20ForTest, ERC20, IERC20} from '@contracts/for-test/ERC20ForTest.sol';
import {CoinForTest} from '@contracts/for-test/CoinForTest.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';

import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * @title  Contracts
 * @notice This contract initializes all the contracts, so that they're inherited and available throughout scripts scopes.
 * @dev    It exports all the contracts and interfaces to be inherited or modified during the scripts dev and execution.
 */
abstract contract Contracts {
  // --- Helpers ---
  address public deployer;
  address public governor;
  bytes32[] public collateralTypes;

  // --- Base contracts ---
  ISAFEEngine public safeEngine;
  ITaxCollector public taxCollector;
  IAccountingEngine public accountingEngine;
  ILiquidationEngine public liquidationEngine;
  IOracleRelayer public oracleRelayer;
  ISurplusAuctionHouse public surplusAuctionHouse;
  IDebtAuctionHouse public debtAuctionHouse;
  IStabilityFeeTreasury public stabilityFeeTreasury;
  mapping(bytes32 => ICollateralAuctionHouse) public collateralAuctionHouse;

  // --- Token contracts ---
  CoinForTest public coin;
  CoinForTest public protocolToken;
  mapping(bytes32 => ERC20ForTest) public collateral;
  ICoinJoin public coinJoin;
  IETHJoin public ethJoin;
  mapping(bytes32 => ICollateralJoin) public collateralJoin;

  // --- Oracle contracts ---
  mapping(bytes32 => IBaseOracle) public oracle;

  // --- PID contracts ---
  IPIDController public pidController;
  IPIDRateSetter public pidRateSetter;

  // --- Settlement contracts ---
  IGlobalSettlement public globalSettlement;
}
