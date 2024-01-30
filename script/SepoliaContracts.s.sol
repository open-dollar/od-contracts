// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract SepoliaContracts {
  address public SystemCoin_Address = 0x167c118AAB87c015Ef954dBe2FeD6C87c0038C0a;
  address public ProtocolToken_Address = 0xF76F8C225C3dFAF06Ea46784d3375b5Ef2B83bF5;
  address public ChainlinkRelayerFactory_Address = 0x313b66A9d0f5A13A39074BB961FE194e0c1565f1;
  address public DenominatedOracleFactory_Address = 0x094968ea104CEe2Cdfa007741a5532869c887139;
  address public DelayedOracleFactory_Address = 0xD1a042e702cA92B60abf3e63379475eD5EEC9736;
  address public MintableVoteERC20_Address = 0xf1D19FC41c557aE9cd322FeC00eE8d9E20528031;
  address public MintableERC20_WSTETH_Address = 0xC9b4061eA8429B708A08b5C5954A1756D284D22a;
  address public MintableERC20_CBETH_Address = 0xF7ADA503C5599F18caDc5f6dc63bfdC5983F9574;
  address public MintableERC20_RETH_Address = 0x04B57842D2115413CC702C77827a43DBBA0D7426;
  address public ChainlinkRelayerChild_8_Address = 0xdDF72E94f8797Fb2D05d4ac0A8f1Bf1484D6dB9f;
  address public DenominatedOracleChild_10_Address = 0xfcCd62bFDaB24380A650f786f126f51E282893c0;
  address public DenominatedOracleChild_12_Address = 0x342bd6E8E5634371F273b46A8aD3ec0B4D9f007D;
  address public DelayedOracleChild_ARB_Address = 0xd20e0cb9fb5066f977490894509DE64999D06463;
  address public DelayedOracleChild_WSTETH_Address = 0xE34a4A25A788731Ee3AB9cb5ce78C542b0e0Cd0e;
  address public DelayedOracleChild_CBETH_Address = 0x42b08E1DB4b6d484a0Ba2016Aa89eBF193031028;
  address public DelayedOracleChild_RETH_Address = 0x27fcfba7C01d96f2DD853cFB4b85203284526D37;
  address public TimelockController_Address = 0x1f13CF05126773f182cFBEB7456aCF9929495D2b;
  address public ODGovernor_Address = 0x64A71568B47D365f5a93839fA317ea67D8A14F01;
  address public SAFEEngine_Address = 0x4D3a921E278C4620826328eB0F71e54F9A85Fd2f;
  address public OracleRelayer_Address = 0xF563Eb6872c2FCd94056e6b9886760999fE47313;
  address public SurplusAuctionHouse_Address = 0xB7Dabdfd6dcc91be1A6a18cde0a1cce924AeE4e3;
  address public DebtAuctionHouse_Address = 0x18b070eFEB92dBB4CB5D5fA08e8C542E215e34e3;
  address public AccountingEngine_Address = 0xc0344db20A4bD59E2aa784A897b1b6782ec70e0F;
  address public LiquidationEngine_Address = 0x47d88A6270950741C3E850717c49dc609Ace98c9;
  address public CollateralAuctionHouseFactory_Address = 0x760c61830a17484872a209E1870d5B578c07B1Da;
  address public CoinJoin_Address = 0xe11B1a77f0eAA3116701a6cC862dbC6D9447095B;
  address public CollateralJoinFactory_Address = 0xba1575e55F81aaaCD9ff837E409F82b3E92429Fb;
  address public TaxCollector_Address = 0x4aB8dB2408F109C60ad4a2C093F54177C6e4ff6B;
  address public StabilityFeeTreasury_Address = 0xf51AfC62619895A68b8bA0056EE5ad6dE9306678;
  address public GlobalSettlement_Address = 0xCBe8E8494C0B5C70092C1bB3252D48963A536876;
  address public PostSettlementSurplusAuctionHouse_Address = 0xefD0A1EF8393CC6d9262b14DfB883f2fD3cbA452;
  address public SettlementSurplusAuctioneer_Address = 0x1EB1da0b3441FE51E95D7C1cdc600E056180DffF;
  address public PIDController_Address = 0x5cC64A4cd04248475728138B9cF686C9dC561737;
  address public PIDRateSetter_Address = 0xDCeC4C33ff27EC1A345FCC9F46aDCAF72d995Ee9;
  address public AccountingJob_Address = 0xD32Fd23334f882C86d704A599a451c4484dd1aB5;
  address public LiquidationJob_Address = 0x391CD55b967b55dd559612e95201D4Ac0e341835;
  address public OracleJob_Address = 0x03B5B64AdAE5CF46aC870AAeF6350222942333B3;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0xd3F8690229362cbA261ED76F30c3A6a2a574E5AB;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x8d1f218AEF424b0333CeBccdBDd6aC207Cce1dFc;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xd5bE0708c85e0F0e1990bbe1e07b6AFE9d0d1f7e;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x9A0AbD7bC17E84cBEDdb8B11cFe2fD5caF09FC32;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x21c668Fc66a372dcAa59E80c0Dd5120C486B0387;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x245Fc6aF8E9Cbc9F9DAf7F12A4001a1fb3749937;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x59b263871Eb16c0186fBA10aA5F4D879D5C3f8cE;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x6A4cfa6902194B9239b7174CB999258931B443B9;
  address public Vault721_Address = 0x075E3850f6577842F89695CC0e66d94dB76c4c90;
  address public ODSafeManager_Address = 0x1499dbe31eD0adcedB064AdDf58b1af320D8400d;
  address public NFTRenderer_Address = 0x2534f347ffD076281d3757700697910E4ff077b8;
  address public BasicActions_Address = 0x1B5c1558E68b10E20E19E762faE52B3f51532482;
  address public DebtBidActions_Address = 0x76c87A774f80cd84E4727b543Df638322B5FBF99;
  address public SurplusBidActions_Address = 0x3cA89F41bC3b9ABAeed53e549C4c5972c16C992D;
  address public CollateralBidActions_Address = 0x90Eced4c898A442C1Aa53bD8b477F68c578f27A4;
  address public PostSettlementSurplusBidActions_Address = 0xE6a176ea72B01FE266316c70f721e786c18a14a5;
  address public GlobalSettlementActions_Address = 0x80428b57Ea8779260aca9dBCF0658A2c1CAFe36E;
  address public RewardedActions_Address = 0x9b641694a9d62231fcf7b07D2A8122AA8ad975d1;
}
