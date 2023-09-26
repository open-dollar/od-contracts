// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, FTRG, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV_TOKEN, GOERLI_CAMELOT_V3_FACTORY} from '@script/Registry.s.sol';
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
    collateral[WBTC] = IERC20Metadata(MintableERC20_WBTC_Address);
    collateral[STONES] = IERC20Metadata(MintableERC20_STONES_Address);
    collateral[TOTEM] = IERC20Metadata(MintableERC20_TOTEM_Address);

    systemCoin = SystemCoin(SystemCoin_Address);
    protocolToken = ProtocolToken(ProtocolToken_Address);

    // --- base contracts ---
    safeEngine = SAFEEngine(SAFEEngine_Address);
    oracleRelayer = OracleRelayer(OracleRelayer_Address);
    surplusAuctionHouse = SurplusAuctionHouse(SurplusAuctionHouse_Address);
    debtAuctionHouse = DebtAuctionHouse(DebtAuctionHouse_Address);
    accountingEngine = AccountingEngine(AccountingEngine_Address);
    liquidationEngine = LiquidationEngine(LiquidationEngine_Address);
    coinJoin = CoinJoin(CoinJoin_Address);
    taxCollector = TaxCollector(TaxCollector_Address);
    stabilityFeeTreasury = StabilityFeeTreasury(StabilityFeeTreasury_Address);
    pidController = PIDController(PIDController_Address);
    pidRateSetter = PIDRateSetter(PIDRateSetter_Address);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(GlobalSettlement_Address);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(
      PostSettlementSurplusAuctionHouse_Address
    );
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(SettlementSurplusAuctioneer_Address);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(ChainlinkRelayerFactory_Address);
    uniV3RelayerFactory = UniV3RelayerFactory(UniV3RelayerFactory_Address);
    camelotRelayerFactory = CamelotRelayerFactory(CamelotRelayerFactory_Address);
    denominatedOracleFactory = DenominatedOracleFactory(DenominatedOracleFactory_Address);
    delayedOracleFactory = DelayedOracleFactory(DelayedOracleFactory_Address);

    collateralJoinFactory = CollateralJoinFactory(CollateralJoinFactory_Address);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(
      CollateralAuctionHouseFactory_Address
    );

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(
      CollateralJoinChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address
    );
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address
    );

    collateralJoin[FTRG] = CollateralJoin(
      CollateralJoinChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address
    );
    collateralAuctionHouse[FTRG] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address
    );

    collateralJoin[WBTC] = CollateralJoin(
      CollateralJoinChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address
    );
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address
    );

    collateralJoin[STONES] = CollateralJoin(
      CollateralJoinChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address
    );
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address
    );

    collateralJoin[TOTEM] = CollateralJoin(
      CollateralJoinChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address
    );
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address
    );

    // --- jobs ---
    accountingJob = AccountingJob(AccountingJob_Address);
    liquidationJob = LiquidationJob(LiquidationJob_Address);
    oracleJob = OracleJob(OracleJob_Address);

    // --- governor ---
    timelockController = TimelockController(payable(TimelockController_Address));
    odGovernor = ODGovernor(payable(ODGovernor_Address));

    // --- proxies ---
    vault721 = Vault721(Vault721_Address);
    safeManager = ODSafeManager(ODSafeManager_Address);
    nftRenderer = NFTRenderer(NFTRenderer_Address);

    basicActions = BasicActions(BasicActions_Address);
    debtBidActions = DebtBidActions(DebtBidActions_Address);
    surplusBidActions = SurplusBidActions(SurplusBidActions_Address);
    collateralBidActions = CollateralBidActions(CollateralBidActions_Address);
    rewardedActions = RewardedActions(RewardedActions_Address);
    globalSettlementActions = GlobalSettlementActions(GlobalSettlementActions_Address);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(
      PostSettlementSurplusBidActions_Address
    );

    // --- oracles ---
    systemCoinOracle = IBaseOracle(DenominatedOracleChild_OD_Address);
    delayedOracle[WETH] = IDelayedOracle(DelayedOracleChild_WETH_Address);
    delayedOracle[FTRG] = IDelayedOracle(DelayedOracleChild_FTRG_Address);
    delayedOracle[WBTC] = IDelayedOracle(DelayedOracleChild_WBTC_Address);
    delayedOracle[STONES] = IDelayedOracle(DelayedOracleChild_STONES_Address);
    delayedOracle[TOTEM] = IDelayedOracle(DelayedOracleChild_TOTEM_Address);

    camelotV3Factory = ICamelotV3Factory(GOERLI_CAMELOT_V3_FACTORY);
  }
}
