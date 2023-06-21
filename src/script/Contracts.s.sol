// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// --- Base Contracts ---
import {SystemCoin, ISystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {SAFEEngine, ISAFEEngine} from '@contracts/SAFEEngine.sol';
import {TaxCollector, ITaxCollector} from '@contracts/TaxCollector.sol';
import {AccountingEngine, IAccountingEngine} from '@contracts/AccountingEngine.sol';
import {LiquidationEngine, ILiquidationEngine} from '@contracts/LiquidationEngine.sol';
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

// --- Oracles ---
import {OracleRelayer, IOracleRelayer} from '@contracts/OracleRelayer.sol';
import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle} from '@contracts/oracles/DelayedOracle.sol';
import {ChainlinkRelayer} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

// --- Tokens ---
import {ERC20ForTest, ERC20} from '@contracts/for-test/ERC20ForTest.sol';
import {CoinForTest} from '@contracts/for-test/CoinForTest.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';
import {OracleForTestnet} from '@contracts/for-test/OracleForTestnet.sol';
import {ETHJoinForTest} from '@contracts/for-test/ETHJoinForTest.sol';

// --- Token adapters ---
import {CoinJoin, ICoinJoin} from '@contracts/utils/CoinJoin.sol';
import {ETHJoin, IETHJoin} from '@contracts/utils/ETHJoin.sol';
import {CollateralJoin, ICollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {CollateralJoinFactory, ICollateralJoinFactory} from '@contracts/utils/CollateralJoinFactory.sol';

import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

// --- Proxy Contracts ---
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {HaiProxyRegistry} from '@contracts/proxies/HaiProxyRegistry.sol';
import {HaiProxyFactory} from '@contracts/proxies/HaiProxyFactory.sol';
import {HaiSafeManager} from '@contracts/proxies/HaiSafeManager.sol';

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
  IProtocolToken public protocolToken;
  ISystemCoin public systemCoin;
  mapping(bytes32 => IERC20Metadata) public collateral;
  ICoinJoin public coinJoin;
  IETHJoin public ethJoin;
  ICollateralJoinFactory public collateralJoinFactory;
  mapping(bytes32 => ICollateralJoin) public collateralJoin;

  // --- Oracle contracts ---
  IBaseOracle public systemCoinOracle;
  mapping(bytes32 => IBaseOracle) public oracle;

  // --- PID contracts ---
  IPIDController public pidController;
  IPIDRateSetter public pidRateSetter;

  // --- Settlement contracts ---
  IGlobalSettlement public globalSettlement;

  // --- Proxy contracts ---
  BasicActions public proxyActions;
  HaiProxyRegistry public proxyRegistry;
  HaiProxyFactory public dsProxyFactory;
  HaiSafeManager public safeManager;

  // --- For test contracts ---
  OracleForTestnet public haiOracleForTest;
  OracleForTestnet public ethUsdOracleForTest;
  OracleForTestnet public opEthOracleForTest;
}
