// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract SepoliaContracts {
  address public ChainlinkRelayerFactory_Address = 0x7C7De459742428AE0786d1d2aCF5100Db1EB0387;
  address public DenominatedOracleFactory_Address = 0xd8d4D616dB32164362Cf9904a6c1936a807B0297;
  address public DelayedOracleFactory_Address = 0x4eB15BDeb24031271c61b6f1671E08DFc809e979;
  address public MintableVoteERC20_Address = 0x2F6aeB8D80C0726DEec970F615769f1c989d36b2;
  address public MintableERC20_WSTETH_Address = 0xC586f5022D13de3462bC5456b8F895ef49b02Fb2;
  address public MintableERC20_CBETH_Address = 0x098bbDB3575CA05273837043f9F59946C62201e4;
  address public MintableERC20_RETH_Address = 0x2bF2A9E3A07B9f75fC1b36D56Efd6999b3AF7951;
  address public ChainlinkRelayerChild_8_Address = 0xaD5cA8531180Ab7C0C4666C1e3cCC990A7Aa63ec;
  address public DenominatedOracleChild_10_Address = 0xAdB4104165b0714F334457a47Cd7fdbc73949a7C;
  address public DenominatedOracleChild_12_Address = 0x018903c59D1b254ca8be5FEc27f17747B661Bac2;
  address public DelayedOracleChild_ARB_Address = 0x4cA03fa8711cD805e1e0731cfE453F381753A5fc;
  address public DelayedOracleChild_WSTETH_Address = 0x4F3d439e1f48F853DF1b50dAbc1Cb45A92F38d64;
  address public DelayedOracleChild_CBETH_Address = 0xBbb6d4aa590C98E51A65D9C3c577a435820bDc54;
  address public DelayedOracleChild_RETH_Address = 0x0273627e51693bF8Ff4B384bf9978df72E1b7263;
  address public TimelockController_Address = 0x3D2DA0286758841b59881bc64f821F1FB0Dbe284;
  address public ODGovernor_Address = 0x8132fbC8A9C58C0B35966DB9221F6698aBe1a8FE;
  address public SAFEEngine_Address = 0xBa3a99892B601eFc34F51082AeAc521f322E4980;
  address public OracleRelayer_Address = 0x65a5C8952248AA105cAcD7aB6E2c007bb4B69F94;
  address public SurplusAuctionHouse_Address = 0xCACA0b053d46bDFfea441Cef3364cc4582c72e23;
  address public DebtAuctionHouse_Address = 0xaC427c92a5c3a687c1F8Fa95b885f535f1034FC4;
  address public AccountingEngine_Address = 0x6C0EB178388446CdC0818F8b4ca80d872B598e0c;
  address public LiquidationEngine_Address = 0x5CFc443Db66A8e8C39D9c769fD5EE1c139BaD159;
  address public CollateralAuctionHouseFactory_Address = 0xd31D7574080F2b29Bd61a4037428629b445c35cC;
  address public CoinJoin_Address = 0x2f01Ff86E91EAe7fcEFD7dC7339F74aaB58F0943;
  address public CollateralJoinFactory_Address = 0x6Ff1fe02B2E64338Ed8E25B44AeB084A086121DC;
  address public TaxCollector_Address = 0xF0A280223d037F5c2e0Bd345963b2dF7AE697ef4;
  address public StabilityFeeTreasury_Address = 0x0dE9E5252BEBb25abD4b1992E49f8CC352060fC8;
  address public GlobalSettlement_Address = 0x78FfF4E713EaEd0329E907788F037A170124eE88;
  address public PostSettlementSurplusAuctionHouse_Address = 0x53aCAec26afBfad20a2C92CA7f555e2ABC707a21;
  address public SettlementSurplusAuctioneer_Address = 0x7A83F5Ab23210d1Eb050aFE5f7e9E9a454782ea6;
  address public PIDController_Address = 0x9a18558741691D07618f3D06a883077E528fA9ad;
  address public PIDRateSetter_Address = 0xf65E9F9d2A939069D6FE07d6a7F12a81d4013cf6;
  address public AccountingJob_Address = 0x5178C1A616CaF67184104Cc6555c0310bbB7F6d5;
  address public LiquidationJob_Address = 0xD1D1a18a459d9Be1a7C237578DF1aB3CFf051282;
  address public OracleJob_Address = 0x67cAD916b2572708E352eDE3A16E54F8d353ebDB;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0xF14405230f195287d426616bE103B5227815D40F;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xbb5484cd846685152b0758Fd7265763Fb095698A;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x7B6583a843b41E5CB3E52055452052813496958C;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x965f467706bE40f2020e0eFa85Ef38607d592c65;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x4BaD88483C9C98b76A0eF4413B6f5F19fF5f76D5;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xEe54B801ac028d76d35290816b0b18383b404254;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xD5Caf52F4f2365789f5dC75b5847A5873DABad95;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x3e9D80DD8538222d81dF41cd001D4aDcb096CFc4;
  address public Vault721_Address = 0x445f4bc91D3d96C968044328bF8cE59A7C2D56Da;
  address public ODSafeManager_Address = 0xf98Ef7Ba4E5BaDaD414eAec6EA90DF29fcA75142;
  address public NFTRenderer_Address = 0xa8E7A8A2781269eBee86289C18d42fc5952C9919;
  address public BasicActions_Address = 0x053dDd9738Aa8072cF48B19fC176e94351f960f6;
  address public DebtBidActions_Address = 0xfcAB538555b3aea34181D60e63eB033c008031B9;
  address public SurplusBidActions_Address = 0x468bAA010369E06aB27B011601881cfFEf122fc6;
  address public CollateralBidActions_Address = 0x01d1e78695268cb95876C2Be35409fB3Fd73Af4B;
  address public PostSettlementSurplusBidActions_Address = 0x8d76F570c496EA43B0163B834D8b3232a4cDffFB;
  address public GlobalSettlementActions_Address = 0xa0D4fCe94F3FA94A820D471791ccb35D166672a2;
  address public RewardedActions_Address = 0xC7a8CCFF6f09dC536c164bA6448F87553d60778D;
}
