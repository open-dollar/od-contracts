// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  // NOTE: The last significant change in the Goerli deployment, to be used in the test scenarios
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 12_872_701;

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
    collateral[WBTC] = IERC20Metadata(0x5E0e96b2c318E63EceA56Be06c7dEc0e8E87D5de);
    collateral[STONES] = IERC20Metadata(0x5eb7112b1cC8E6AC08566881c6F4f6508Fd99578);
    collateral[TOTEM] = IERC20Metadata(0x09880394A9034e0337893A201A4B6AAC89bE6Cae);

    systemCoin = SystemCoin(0x8548Dd38Fd5f54173cf349E99379C1FEC945b469);
    protocolToken = ProtocolToken(0xbcc847DdE48E579fa8d98E0d4bd46161A0f84F8A);

    // --- base contracts ---
    safeEngine = SAFEEngine(0xa81aAbe0A4c730E59715aef1a48B83D622022709);
    oracleRelayer = OracleRelayer(0x10028d4ba68900b6894349F9Eaa179d2094A2f00);
    surplusAuctionHouse = SurplusAuctionHouse(0x57927FBF2E396Cb2B246dD412984127200927b87);
    debtAuctionHouse = DebtAuctionHouse(0x8728a476Bc15C08b8b22d08e527B9778e9Bbb32f);
    accountingEngine = AccountingEngine(0x64D93F245F921414416b0FcaDe2C035C67A971D6);
    liquidationEngine = LiquidationEngine(0x5530B52229bA616Ac300F479268c1b7381eF16a4);
    coinJoin = CoinJoin(0xfc63F2CfbfB09131a87452dF713E84885fFF9466);
    taxCollector = TaxCollector(0x18059871eA044bFE1e92F5EF0D5D6e621160C94d);
    stabilityFeeTreasury = StabilityFeeTreasury(0xB8F9619ADC510F2B120A998AeEeDa42cABCB6990);
    pidController = PIDController(0xB6F2aCB8CBD4A2BEC57e72e32b424CF16350c4fc);
    pidRateSetter = PIDRateSetter(0x4048AC752280F22b398643E6726660147fbcF1A5);

    // --- global settlement ---
    globalSettlement = GlobalSettlement(0xA33f662c10D8eDa75D9f511262e3347d3716568A);
    postSettlementSurplusAuctionHouse = PostSettlementSurplusAuctionHouse(0x696eec613235c8a9BF47ddB5686799CBea000ecC);
    settlementSurplusAuctioneer = SettlementSurplusAuctioneer(0xf51A2E5c38b6B6B6ddF2c26E9f8b6f006e0186d9);

    // --- factories ---
    chainlinkRelayerFactory = ChainlinkRelayerFactory(0x62156A3371c3fC695E184Cc032A25FE94dAe78A4);
    uniV3RelayerFactory = UniV3RelayerFactory(0xC5Ca8250D96A5aE1f7A9A591FD24747e418E3bDf);
    denominatedOracleFactory = DenominatedOracleFactory(0x757Fef08130b38cfC549c73DDEFCCA0E227E29A9);
    delayedOracleFactory = DelayedOracleFactory(0xcf708e72Ae4797EB4D2bcfa1C6F1215D4ef87883);

    collateralJoinFactory = CollateralJoinFactory(0xdcB44723463E2635416e8508dA8a1caEf08D5f1B);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0xD456de3189A77b6edbf928139f1eCEf2cd3e2644);

    // --- per token contracts ---
    collateralJoin[WETH] = CollateralJoin(0xFb0758b07B4260958Cb1589091489E2A2d9af513);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x40B5dAD43D2582d5c3975c3B1b55c36b7D2812c8);

    collateralJoin[OP] = CollateralJoin(0x66b42623a06744d40dF27bb32816d4d1A6905914);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0xbe5940d9572DD1e8A594b5691894CDb8eb130BE6);

    collateralJoin[WBTC] = CollateralJoin(0xfa27ed51bd028085C29b69dced2bDdd3FA777Ecd);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0x92591B6EA0552E1B09d1fAB697628dA306401aD6);

    collateralJoin[STONES] = CollateralJoin(0xDc89c1dc710847a2CaffA65680bf3f182bFd5d0f);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0x0F61583E8e558D9D1caA76533db7C97d7Ef76592);

    collateralJoin[TOTEM] = CollateralJoin(0xa9002Dd9Dc6867E5D5f41152C926317B834241e6);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0xB0e3dd0fFA9DCc0F6866711bFFDa13406e2850C9);

    // --- jobs ---
    accountingJob = AccountingJob(0x3cE8DD6D2496190B0769A9743567e1919cDB1e47);
    liquidationJob = LiquidationJob(0xAD038eFce5dE9DBC1acfe2e321Dd8F2D6f16e26b);
    oracleJob = OracleJob(0x3e05f863afa6ACcAE0ED1e535559c881CB3f6b85);

    // --- proxies ---
    proxyFactory = HaiProxyFactory(0xCA969d78b986dE02CC6E44194e99C0b2F77F3cEc);
    proxyRegistry = HaiProxyRegistry(0x8FF12e19f1f246D0257D478C90eB47a960F4DBb4);
    safeManager = HaiSafeManager(0xc0C6e2e5a31896e888eBEF5837Bb70CB3c37D86C);

    basicActions = BasicActions(0x0c3287b5C1Ea5b04E90A3d1af02B78544b33f573);
    debtBidActions = DebtBidActions(0xFb47e938010Cbd6f6b5953Be7aDc10F9c07d5CAA);
    surplusBidActions = SurplusBidActions(0xd7d804b859B2C23B310db2510316426D99976ff6);
    collateralBidActions = CollateralBidActions(0x85f9a28F7F7e343e1806E112272bd783eA73b4B9);
    rewardedActions = RewardedActions(0xdD481aF67e8dfee190545Ae1b97c36373BfA1a7e);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0x4845E891dB00979B0A017182b1dad52cbc75aEF0);
    delayedOracle[WETH] = IDelayedOracle(0x6fEbFFd8174c950D4D357ce9960F68fef4769Bed);
    delayedOracle[OP] = IDelayedOracle(0x409e0666ea8ECea543C1E95288493CB4fe0C7773);
    delayedOracle[WBTC] = IDelayedOracle(0x1c31737D56925B862EFfd9d256c10cC71Ed46949);
    delayedOracle[STONES] = IDelayedOracle(0x40E2A30E6b2e3d626eD93A4067E911632C54B07E);
    delayedOracle[TOTEM] = IDelayedOracle(0x9881c2f838BbC4D8E8624F7739E93EF6D407b52f);
  }
}
