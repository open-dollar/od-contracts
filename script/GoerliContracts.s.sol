// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x5F11Cd5E08990Ec6eaAe08D9Cb8ef34671F98A48;
  address public UniV3RelayerFactory_Address = 0x01AF2B94B9eae09d213852b7f1f596D584750DDd;
  address public CamelotRelayerFactory_Address = 0x526e3385363291be2F591738AF6fed2Be1e71c5E;
  address public DenominatedOracleFactory_Address = 0x981f04a814E90621421616A5D80f287461BF9d4E;
  address public DelayedOracleFactory_Address = 0x93B9a7A0e204a5303516fA1078Cca12fdEEa902b;
  address public MintableVoteERC20_Address = 0x6cf4f5A945B956355Bc33b992DF87C8A445855E1;
  address public MintableERC20_WSTETH_Address = 0x62AD1FEBB228bF824A63aD60081782CdB79a3D5F;
  address public MintableERC20_CBETH_Address = 0xe50359EE05Bca07f21BfDBac94559db80BaaAE6D;
  address public MintableERC20_RETH_Address = 0x9a03853710513A0FE6DE50e660e96471D5ECEB94;
  address public MintableERC20_MAGIC_Address = 0x4785cE54fAc50A793bEf8D7B0fBcbE476726ed51;
  address public ChainlinkRelayerChild_11_Address = 0x11a33A7A2b6F3fc120b833Dad41e09364A842756;
  address public DenominatedOracleChild_13_Address = 0xEE1AABfD4CaC53D243836741A1691E4C553d320c;
  address public DenominatedOracleChild_15_Address = 0xF08190666A6c5178Bb08D39ce8594B2ff25Aed5c;
  address public DenominatedOracleChild_17_Address = 0x44f79230a7dd2cb3cDF81CA78A0A8cBBE54AF063;
  address public DelayedOracleChild_ARB_Address = 0x2DA74BaE194DCd0F146c3faE6922B38CD513739f;
  address public DelayedOracleChild_WSTETH_Address = 0x2EDc5bf6718fc1C2d8B9c7AFb50F6da0Aff14d94;
  address public DelayedOracleChild_CBETH_Address = 0x1D87044E73C43469af5d851D7b1A4Abd0aAA145D;
  address public DelayedOracleChild_RETH_Address = 0x213384885cF248B6AD30B6dF6AAc77E6298063cc;
  address public DelayedOracleChild_MAGIC_Address = 0x30825e7aD8E607101693c03b8aF114a0FCA25256;
  address public SystemCoin_Address = 0xc065c5d279E581aCAd056fDF825B0a55EAb9884e;
  address public ProtocolToken_Address = 0x52C0d18d7771ad9e0c8b700c84a4e845b2C3a41A;
  address public SAFEEngine_Address = 0x6609C41a6eCf555ceA3766D0B671e6E7601360e5;
  address public OracleRelayer_Address = 0x50573a7C750CEbaa4F269905bfAe87C1a53d52C1;
  address public SurplusAuctionHouse_Address = 0x7398B59C5BF71f78c1aE27341ceC089Ed9B91fb9;
  address public DebtAuctionHouse_Address = 0x4e3eb382Add436542188b37b2d10077fb6E4DCF7;
  address public AccountingEngine_Address = 0xf916f00f0BA6C0bb74ff7958e225eD7091017732;
  address public LiquidationEngine_Address = 0xbA63249276e48CCa3f19A1FC731cCf969d88Dd38;
  address public CollateralAuctionHouseFactory_Address = 0x321d278E1bDF686145C8fD185dDdA2178A3e3424;
  address public CoinJoin_Address = 0xf077E445B4D60891ABFfE6294F08c12c4fAD51F9;
  address public CollateralJoinFactory_Address = 0x91931AcaDbd3c94305787dAb972DC9b414412040;
  address public TaxCollector_Address = 0xd7363C24068191a8DFFeA32C270298347c5D533f;
  address public StabilityFeeTreasury_Address = 0xfB91c222Bc1Aae5d3Ee922E90ab7Aa58De0E16c7;
  address public GlobalSettlement_Address = 0x6fABa65097693F251aBC7589465e591cA646Ca2b;
  address public PostSettlementSurplusAuctionHouse_Address = 0x10B6097733e9C4d7025Dee03B01F48a9989515Ab;
  address public SettlementSurplusAuctioneer_Address = 0x6759EEEe4194A89D0f9900EDC2A0d920fB860e38;
  address public PIDController_Address = 0x5B8d3C6909DA6baa436be102d16bBfA5a6D8c1a4;
  address public PIDRateSetter_Address = 0xcD62999559dE678664e2f59230C8Aa3e6B86efdb;
  address public AccountingJob_Address = 0xa6D3F5162F711240250472eAEfdAdC706C1F3a33;
  address public LiquidationJob_Address = 0xc938F05af0949D3de802DC874599dEE9BaCB250b;
  address public OracleJob_Address = 0x920553927193474b4E25Fb73Ae51D1DdA0A5283f;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x2006A04Cd2C46fd6421845f4Ee2B7A2804A45394;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xA7164b02514a4532a841347377F182Cc47f6Bd3B;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x1FbD7112aF8de5DBB7a26100417A4dfaF50c109b;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x446f0Fb6798e6AfA21234Fe4d8aa793DEee1efCF;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xf6B63F93889C70ED1dCbfF8d36FF3f58738651f2;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x9a645Aacf89b54a2a2e04326d5091a7cEbd5a61e;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x30640b29Aafe0c958187d951a2a443C3eca3b3E1;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x46E67d383934c2f9C97eB733102C248Aec3f6Df2;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0x4ec74508fc6E2eB524c70c894C5878a94A82b9bd;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0x27C698F2206c28b05393a792c96E491F8f8E1644;
  address public TimelockController_Address = 0x9Cbbd0d4C5d0f58e7bBf0be0a991B671b1e39402;
  address public ODGovernor_Address = 0x9B1B0e048F5575bb164F3d80a105613ECb572154;
  address public Vault721_Address = 0xea319d259e93f68Ed6414134ffCFA4912Bea85dB;
  address public ODSafeManager_Address = 0xe0e95c4BB8A6ae4822DC8760563AE1e6d8bBd75f;
  address public NFTRenderer_Address = 0x1c9F0A653Ae53547F54C868EF3BfbeaaEcd262bd;
  address public BasicActions_Address = 0x22d0257DB39f4191e5df2cb1D23163208FAF7870;
  address public DebtBidActions_Address = 0xc5b40e23fe1f6a26D85B0956A396f9F64551Ec94;
  address public SurplusBidActions_Address = 0x2ff7998E6C491aE85Cdb7979eE8F003e2f094513;
  address public CollateralBidActions_Address = 0x1e08dFdd274BAe08059112920A413eB9Ac3D0CA8;
  address public PostSettlementSurplusBidActions_Address = 0x7E184ed247Ff368De5a61Bf0C68dC23525F78cD6;
  address public GlobalSettlementActions_Address = 0x7D47f78C7989A6600EA1A921D8eF9FA52153D272;
  address public RewardedActions_Address = 0x9b57f00Ed2509e365E7b8C84e1B68aF5b5b9AC39;
}
