// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, FTRG, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams, GoerliContracts {
  // NOTE: The last significant change in the Goerli deployment, to be used in the test scenarios
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 12_872_701;

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(FTRG);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);

    // --- utils ---
    delegatee[FTRG] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(ARB_GOERLI_WETH);
    collateral[FTRG] = IERC20Metadata(ARB_GOERLI_GOV_TOKEN);
    collateral[WBTC] = IERC20Metadata(erc20ForTestnetWBTC);
    collateral[STONES] = IERC20Metadata(erc20ForTestnetSTONES);
    collateral[TOTEM] = IERC20Metadata(erc20ForTestnetTOTEM);

    systemCoin = SystemCoin(systemCoinAddr);
    protocolToken = ProtocolToken(protocolTokenAddr);

    // --- base contracts ---
    safeEngine = SAFEEngine(safeEngineAddr);
    oracleRelayer = OracleRelayer(oracleRelayerAddr);
    surplusAuctionHouse = SurplusAuctionHouse(surplusAuctionHouseAddr);
    debtAuctionHouse = DebtAuctionHouse(debtAuctionHouseAddr);
    accountingEngine = AccountingEngine(accountingEngineAddr);
    liquidationEngine = LiquidationEngine(liquidationEngineAddr);
    coinJoin = CoinJoin(coinJoinAddr);
    taxCollector = TaxCollector(taxCollectorAddr);
    stabilityFeeTreasury = StabilityFeeTreasury(stabilityFeeTreasuryAddr);
    pidController = PIDController(PIDControllerAddr);
    pidRateSetter = PIDRateSetter(PIDRateSetterAddr);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(globalSettlementAddr);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(postSettlementSurplusAuctionHouseAddr);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(settlementSurplusAuctioneerAddr);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(chainlinkRelayerFactoryAddr);
    uniV3RelayerFactory = UniV3RelayerFactory(uniV3RelayerFactoryAddr);
    denominatedOracleFactory = DenominatedOracleFactory(denominatedOracleFactoryAddr);
    delayedOracleFactory = DelayedOracleFactory(delayedOracleFactoryAddr);

    collateralJoinFactory = CollateralJoinFactory(collateralJoinFactoryAddr);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(collateralAuctionHouseFactoryAddr);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(collateralJoinChild_WETHAddr);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(collateralAuctionHouseChild_WETHAddr);

    collateralJoin[FTRG] = CollateralJoin(collateralJoinDelegatableChild_OPAddr);
    collateralAuctionHouse[FTRG] = CollateralAuctionHouse(collateralAuctionHouseChild_OPAddr);

    collateralJoin[WBTC] = CollateralJoin(collateralJoinChild_WBTCAddr);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(collateralAuctionHouseChild_WBTCAddr);

    collateralJoin[STONES] = CollateralJoin(collateralJoinChild_STONESAddr);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(collateralAuctionHouseChild_STONESAddr);

    collateralJoin[TOTEM] = CollateralJoin(collateralJoinChild_TOTEMAddr);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(collateralAuctionHouseChild_TOTEMAddr);

    // --- jobs ---
    accountingJob = AccountingJob(accountingJobAddr);
    liquidationJob = LiquidationJob(liquidationJobAddr);
    oracleJob = OracleJob(oracleJobAddr);

    // --- proxies ---
    vault721 = Vault721(vault721Addr);
    safeManager = ODSafeManager(haiSafeManagerAddr);

    basicActions = BasicActions(basicActionsAddr);
    debtBidActions = DebtBidActions(debtBidActionsAddr);
    surplusBidActions = SurplusBidActions(surplusBidActionsAddr);
    collateralBidActions = CollateralBidActions(collateralBidActionsAddr);
    rewardedActions = RewardedActions(rewardedActionsAddr);
    globalSettlementActions = GlobalSettlementActions(globalSettlementActionsAddr);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(postSettlementSurplusBidActionsAddr);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x4845E891dB00979B0A017182b1dad52cbc75aEF0);
    delayedOracle[WETH] = IDelayedOracle(delayedOracleChild1Addr);
    delayedOracle[FTRG] = IDelayedOracle(delayedOracleChild2Addr);
    delayedOracle[WBTC] = IDelayedOracle(delayedOracleChild3Addr);
    delayedOracle[STONES] = IDelayedOracle(delayedOracleChild4Addr);
    delayedOracle[TOTEM] = IDelayedOracle(delayedOracleChild5Addr);
  }
}
