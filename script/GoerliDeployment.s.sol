// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  // NOTE: The last significant change in the Goerli deployment, to be used in the test scenarios
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 13_602_802;

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(OP);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);

    // --- utils ---
    delegatee[OP] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);
    collateral[WBTC] = IERC20Metadata(0xA5553A3ec007914fC12d648cd9A00164535BFf98);
    collateral[STONES] = IERC20Metadata(0x07Fe26b7a9247311b1587510BAd5B02CD33a7F64);
    collateral[TOTEM] = IERC20Metadata(0x51d5F9Cc09394Ee3cF2601b18F8Af931e19460Bd);

    systemCoin = SystemCoin(0x82535c9585A070BfA914924F6D83F7162D17A869);
    protocolToken = ProtocolToken(0xbcc847DdE48E579fa8d98E0d4bd46161A0f84F8A);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x4ADe84BB4da143af07F9f89E00B65E3a08E2035A);
    oracleRelayer = OracleRelayer(0xB6AA4B291ff95565dd6ECd9F7C811372468520ff);
    surplusAuctionHouse = SurplusAuctionHouse(0x8e75186BC45ffEbedaA90773670a9f805e661894);
    debtAuctionHouse = DebtAuctionHouse(0x8D602868C1d00F2A428719d680F81BDe6E1e50A1);
    accountingEngine = AccountingEngine(0x1eC0925d31590dAE3bB9aB7DE65109090B2c510a);
    liquidationEngine = LiquidationEngine(0xd7d402568046651FEDef30AD62d1b876b76F5EE6);
    coinJoin = CoinJoin(0x8D0452eD670872b91Ee0d4c0450af01840974025);
    taxCollector = TaxCollector(0x99fBdeD15FCCC5D2284c3b07E438C76D3A9d045C);
    stabilityFeeTreasury = StabilityFeeTreasury(0xb6f335AaC75184B8b18Cd5aF12Bd183C2Bd9b571);
    pidController = PIDController(0xB800827d75074Df2152A75aB84fE06351F3E105f);
    pidRateSetter = PIDRateSetter(0xAafd9E0f3f3afD662bBE6819eaaEB7099bf22E4E);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0x84DFaefaB51Ce02DE5B7811983B68C9f402f99dd);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0xD486fD908B6637eaEE2dD625A48537a2A4Ed826f);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0x8145F99712aA294523403C2B88198D92Da66d6b2);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0x47F13CBB7E2dc7D52c67846aF2e62Cde32B5fE18);
    uniV3RelayerFactory = UniV3RelayerFactory(0x877979625830b3b419824a5ED657c8ae47267207);
    denominatedOracleFactory = DenominatedOracleFactory(0xBECb90242304F52E777A0AC559F9971c89894872);
    delayedOracleFactory = DelayedOracleFactory(0x8d1Cd45Bd8ba43fBcC03F36Bc7D7304Cb1d4D0Fb);

    collateralJoinFactory = CollateralJoinFactory(0xeB7E2307f2994e9E7C5153E1a3B3407a4BF9B421);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0xf979110B7EEDce98603b504f73Fd71Db5BE8146a);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0x344a156575B6528CC6FfB2BDCA11462B2E1e8b36);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x1f89b2f02ff17368417e4D106FAd1E33e448811e);

    collateralJoin[OP] = CollateralJoin(0x4A54a29b9bA80bfd0056E8E7a96329E4e6906d6d);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x742De44F54b157a73484816ECBe71769861956A4);

    collateralJoin[WBTC] = CollateralJoin(0x523a000b6A840c2927a3f9333F585d01565A9E9A);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0x3A1Ca3d9c7B5c761776ADd7868D4983d9396B987);

    collateralJoin[STONES] = CollateralJoin(0xAfE7A0565B8Bf0203DCF88D606fa49CF5E13E84f);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0xFa17ae1cB6b887D6ce074116a09130eF39badAF7);

    collateralJoin[TOTEM] = CollateralJoin(0x96959F8fBBe22eA0d4581d8D2274Ad60e1Fc90dd);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0xB54D5EBDE6F1c220ce846CE1a64274dfC0dF922b);

    // --- jobs ---
    accountingJob = AccountingJob(0x2b0Abebdd29c0a0A82aF96E76709c771cCaD194b);
    liquidationJob = LiquidationJob(0xbDdCBE327610803B681868A9AE4EF61feA56DD9E);
    oracleJob = OracleJob(0xE181f3dE1E196CD939E1006674C9466ACdF74143);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0x129ed50D28B4A85F3862B25413142FE24eEd185c);
    safeManager = HaiSafeManager(0x033Fa671B4743f343b3CA685845e48a412EC0302);

    basicActions = BasicActions(0xD34D69b9063A641F62F2a39CADd2996B54AC1C0b);
    debtBidActions = DebtBidActions(0xb05984f73E7AcD8450B3244A0AB7C073065F4dF3);
    surplusBidActions = SurplusBidActions(0x034c184E034c992AbE22F8a7930C03483586E459);
    collateralBidActions = CollateralBidActions(0x0c852243Bc5891aC2D418c3b507eBEE99d781e04);
    postSettlementSurplusBidActions = PostSettlementSurplusBidActions(0xa79653eE7CB9ED9f42f026F799433c9aaa4e8A44);
    globalSettlementActions = GlobalSettlementActions(0x3ab8129bb9456aE25538f1B3a0694f2D15357110);
    rewardedActions = RewardedActions(0x39407e84B77eAF49176740704b9a9eD9a6B2DA4c);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x55464C5840F743214e68Cf1f5c227C568D5d82AA);
    delayedOracle[WETH] = IDelayedOracle(0xF7a2523c8E1CDD0583eb71E4a91D4aaa24159132);
    delayedOracle[OP] = IDelayedOracle(0x2A84bC2996f8C9641d8Edfe15Ca2A0556cEd75A0);
    delayedOracle[WBTC] = IDelayedOracle(0x24E3b28820b2E8338D871CdAf4e7541386B5B6E1);
    delayedOracle[STONES] = IDelayedOracle(0x692f1685Bad5197733Fc4F4110447D85af5fedF6);
    delayedOracle[TOTEM] = IDelayedOracle(0x40Ff638e6a65C37DAb9B660Cf01bc9729d9D319c);
  }
}
