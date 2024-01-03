// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {SepoliaParams, WSTETH, ARB, CBETH, RETH} from '@script/SepoliaParams.s.sol';
import {AnvilContracts} from '@testlocal/nft/anvil/deployment/AnvilContracts.t.sol';
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';

abstract contract AnvilDeployment is Contracts, SepoliaParams, AnvilContracts {
  /**
   * @notice All the addresses that were deployed in the Anvil deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the anvil test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(ARB);
    collateralTypes.push(WSTETH);
    collateralTypes.push(CBETH);
    collateralTypes.push(RETH);

    // --- utils ---
    delegatee[ARB] = governor;

    // --- ERC20s ---
    collateral[ARB] = IERC20Metadata(MintableVoteERC20_Address);
    collateral[WSTETH] = IERC20Metadata(MintableERC20_wstETH_Address);
    collateral[CBETH] = IERC20Metadata(MintableERC20_cbETH_Address);
    collateral[RETH] = IERC20Metadata(MintableERC20_rETH_Address);

    erc20[ARB] = MintableERC20(MintableVoteERC20_Address);
    erc20[WSTETH] = MintableERC20(MintableERC20_wstETH_Address);
    erc20[CBETH] = MintableERC20(MintableERC20_cbETH_Address);
    erc20[RETH] = MintableERC20(MintableERC20_rETH_Address);

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
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(PostSettlementSurplusAuctionHouse_Address);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(SettlementSurplusAuctioneer_Address);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(ChainlinkRelayerFactory_Address);
    denominatedOracleFactory = DenominatedOracleFactory(DenominatedOracleFactory_Address);
    delayedOracleFactory = DelayedOracleFactory(DelayedOracleFactory_Address);

    collateralJoinFactory = CollateralJoinFactory(CollateralJoinFactory_Address);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(CollateralAuctionHouseFactory_Address);

    // --- per token contracts ---
    collateralJoin[ARB] =
      CollateralJoin(CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address);
    collateralAuctionHouse[ARB] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address
    );

    collateralJoin[WSTETH] =
      CollateralJoin(CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address);
    collateralAuctionHouse[WSTETH] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address
    );

    collateralJoin[CBETH] =
      CollateralJoin(CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address);
    collateralAuctionHouse[CBETH] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address
    );

    collateralJoin[RETH] =
      CollateralJoin(CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address);
    collateralAuctionHouse[RETH] = CollateralAuctionHouse(
      CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address
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
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(PostSettlementSurplusBidActions_Address);

    // --- oracles ---
    delayedOracle[ARB] = IDelayedOracle(DelayedOracleChild_15_Address);
    delayedOracle[WSTETH] = IDelayedOracle(DelayedOracleChild_16_Address);
    delayedOracle[CBETH] = IDelayedOracle(DelayedOracleChild_17_Address);
    delayedOracle[RETH] = IDelayedOracle(DelayedOracleChild_18_Address);

    // --- tokens ---
  }
}
