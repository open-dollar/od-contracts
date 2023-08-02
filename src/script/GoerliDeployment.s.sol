// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, AGOR, WBTC} from '@script/GoerliParams.s.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  // uint256 constant GOERLI_DEPLOYMENT_BLOCK = 8_503_536;
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 10_000_000;

  // --- Mintable ERC20s ---
  // ERC20ForTestnet constant ERC20_WBTC = ERC20ForTestnet(0x71544c0d4A343AA6136775cCB093e277E75A700f);

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(AGOR);
    // collateralTypes.push(WBTC);

    // --- utils ---
    delegatee[AGOR] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(ARB_GOERLI_WETH);
    collateral[AGOR] = IERC20Metadata(ARB_GOERLI_GOV);
    // collateral[WBTC] = IERC20Metadata(ERC20_WBTC);

    // change these
    systemCoin = SystemCoin(0xDE477f42368128CB3B0b29E214bd859f1A3719Ef);
    protocolToken = ProtocolToken(0x6b7802EF43EaEA91713094a2EC0FA55EeC39Fa44);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x647F0f0999744e2F2f8949B52e19137e231Bd936);
    oracleRelayer = OracleRelayer(0xf19FA6E563991062D9e572AD7c5d6e345e914e30);
    liquidationEngine = LiquidationEngine(0x191F50efEB89e585D5fC7BcBD90418e4010646aC);
    coinJoin = CoinJoin(0xf9F71E1a6C8a7FEB65eAf5803c4dB2B1fc0B20ad);
    surplusAuctionHouse = SurplusAuctionHouse(0x7457854b2F096663df8c037f4673d4AA97cB77f3);
    debtAuctionHouse = DebtAuctionHouse(0xAfbbAb6374Ab1f0B517B3f7536c22217c789935A);
    accountingEngine = AccountingEngine(0x664b13E4A3d0c78365f85cffc606B475f75852d6);
    taxCollector = TaxCollector(0x18005c724403caa55cB5edB482996Aa4dBE9cc8c);
    stabilityFeeTreasury = StabilityFeeTreasury(0xd0c82643629daA4B15AE49244395da76F25A8d1D);
    pidController = PIDController(0x4ac2ab75d61f9F39e48927F1745Edb330CD76bC7);
    pidRateSetter = PIDRateSetter(0x571b07f850d5E9d44fA8EDbe82C96436027B5aFE);
    globalSettlement = GlobalSettlement(0xcFbFb81c7Eaab8643338FD453d76446435E2B73E);

    // --- factories ---
    collateralJoinFactory = CollateralJoinFactory(0x03f86c07c7A04a48DB18d16fFdeC6f147ff63072);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x991CA45f905b11810B9eDD6071F4Caaa81e74a57);

    // --- token adapters ---
    collateralJoin[WETH] = CollateralJoin(0xebeD5e53193085cAf0a1539428985e83baE4448b);
    collateralJoin[AGOR] = CollateralJoin(0x4D5EE29C69B26970021f945Ee9e7Ea5884E92c99);

    // --- collateral auction houses ---

    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0xB0CfCB2112747ceC1fD0372D3217962530a13048);
    collateralAuctionHouse[AGOR] = CollateralAuctionHouse(0x5a40684690d3C79CAdc08206d3D352Af1AC208b6);
    
    //OP auction houses
    //collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x166425Cc84996DC0d8fEaDa66F86055AAE8f8209);
    //collateralAuctionHouse[OP] = CollateralAuctionHouse(0xeAfB6be474e84fC5f3aF7bbaD39D89A5764D4D36);
    //collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0x724A7b53c0B81DDB0654e012c94667730CBa1837);
    //collateralAuctionHouse[STONES] = CollateralAuctionHouse(0x22a804F6685f96dE8CD81aba0C85fe49884274f8);
    //collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x24CF3ddF28d7a2e046Ea9bD1B6908D8B33AAB873);

    // --- jobs ---
    accountingJob = AccountingJob(0x9c6fc600d9673b322C6Bb0835008a0f8229d11b2);
    liquidationJob = LiquidationJob(0xAF729A93526026c63Ada37015d2A0aa3B149913e);
    oracleJob = OracleJob(0xCC81b8E22Bc48133125BDa642C452EC6A52853C8);

    // --- proxies ---
    dsProxyFactory = HaiProxyFactory(0x1A020C90e6F43851e7D65e6824400366aA35eAD3);
    proxyRegistry = HaiProxyRegistry(0x61984D43B50395F446D3199EcE75d5E089f3d2E1);
    safeManager = HaiSafeManager(0x7655Be7cC6d9eAfB61c594Ab767377CeF57693b2);
    proxyActions = BasicActions(0xbeFee933f276Ff5A684d95c3fC8E255a054Ee1dF);

    // --- oracles ---
    delayedOracle[WETH] = IDelayedOracle(0xD2b5b036B89EE7FDb2cEbC0D0583F7b7eAdf9193);
    delayedOracle[AGOR] = IDelayedOracle(0x1e263D04508728231BB4E0AA2828Fe75c049c97F);

    haiOracleForTest = OracleForTestnet(0xDB0dd24A4Ff6236a76D5c231Ed187e9cAd02dd40);
    opEthOracleForTest = OracleForTestnet(0x24f243E0619118a4cC5aF787f16834bE121DD299);
  }
}
