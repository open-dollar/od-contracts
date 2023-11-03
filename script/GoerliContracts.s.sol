// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x0Ed89D4655b2fE9f99EaDC3116b223527165452D;
  address public UniV3RelayerFactory_Address = 0x0b283A5505E9675194674E6b42b30DC33c800794;
  address public CamelotRelayerFactory_Address = 0x7C9Cd93e6BCF520B6cE5FE51fb4124e0D8DF595B;
  address public DenominatedOracleFactory_Address = 0x0F12d95BA60dE2e723F27EDfa0f234A2E4D64005;
  address public DelayedOracleFactory_Address = 0x621da9683c75b19a76F44A9d19744B8D1deC5aD7;
  address public MintableVoteERC20_Address = 0x43351fA21a4aC1f7A4D114C8Cf78246C93D712c1;
  address public MintableERC20_WSTETH_Address = 0xCd5261356706Fd4D8f417F9BffB9dBE575CaE996;
  address public MintableERC20_CBETH_Address = 0x38213F94F27C383E6eAFB67327B6a54be3d2DEF9;
  address public MintableERC20_RETH_Address = 0x4fdAb70D291799cA63314F3b7a780732e27979e9;
  address public MintableERC20_MAGIC_Address = 0xE89B7d239764a3D1266aD5c6DCADB5ccfdfFC2cD;
  address public DenominatedOracleChild_13_Address = 0x8eC90D60d0c80f4E93C1bB73dF3815C1877DA0C8;
  address public DenominatedOracleChild_15_Address = 0x73A9C6adE2426b557A321f948752a85963105b90;
  address public DenominatedOracleChild_17_Address = 0xcAaf6635Ac85eb66B6fDD124cCfb4E7B5Dd837c0;
  address public DelayedOracleChild_ARB_Address = 0xbC6F85FfC0596292D32Cba29691c8f46c10692D6;
  address public DelayedOracleChild_WSTETH_Address = 0x623b8fBf767eEC3B75Ca192aa265C7b05Ffa8d07;
  address public DelayedOracleChild_CBETH_Address = 0x77b885Ee084db3C23bCDFe016A5e15A69c79247E;
  address public DelayedOracleChild_RETH_Address = 0xBAc17EEB9188d56e066d974b62eE4c0cFA6D02ca;
  address public DelayedOracleChild_MAGIC_Address = 0xF849f5733f3D04b213c246C42Af4e35B91A75E40;
  address public SystemCoin_Address = 0xa21c089E7741b30d5c111AB433c426B2e4Eb800e;
  address public ProtocolToken_Address = 0xE39C8d9E417d922b9fd77B451Cd7969fE2ad4ce2;
  address public TimelockController_Address = 0x9A71D25E8E144EE107F19353bB4e24d7493557b6;
  address public ODGovernor_Address = 0xda2134f60E904a830B479181fd188D852A8b3Fa5;
  address public SAFEEngine_Address = 0xC19d27A3912fbf3fd4255CDD081Df54472550C82;
  address public OracleRelayer_Address = 0xc862BbD45bAd4f41582155483929ad0fFAB66eB4;
  address public SurplusAuctionHouse_Address = 0xC08F3a8626636c7162e35b128Cb8ea41318f1A58;
  address public DebtAuctionHouse_Address = 0xf28D6994f3862453D7c0518657B731f9d5C82161;
  address public AccountingEngine_Address = 0x3ffcbAd81834BD791Aa64a23b4eA361Ed0576f96;
  address public LiquidationEngine_Address = 0xa7cd8329A47CdF50bd39C8dD68E851Bc9C3C7754;
  address public CollateralAuctionHouseFactory_Address = 0x0D72C175d621EcED29d82Fe987C5DF5643348a86;
  address public CoinJoin_Address = 0xa0fA52A075E7a4AbfB7336F9677f287EAB5aDE37;
  address public CollateralJoinFactory_Address = 0x2091531FF33a363cd73f6e50b53E83D7977277DB;
  address public TaxCollector_Address = 0x7B0C2618d6e117bfAf5cd6Ff608d30221546672C;
  address public StabilityFeeTreasury_Address = 0x20Cd57DaEdff0aA61CF4bE03bdcd80483e1338Ac;
  address public GlobalSettlement_Address = 0x6C7F5D57fBADb0b6690450e6EbfA64841cB7120C;
  address public PostSettlementSurplusAuctionHouse_Address = 0x03506301B28E96A754581eFcf510D8701D55F204;
  address public SettlementSurplusAuctioneer_Address = 0xF53b0A5b5F24ea49CdBaC499859f58463DCF73b1;
  address public PIDController_Address = 0xe6ab174bfEa01d78Bf8F95C3D83B53Dd12929987;
  address public PIDRateSetter_Address = 0xdf613eDF8bD78F052a33a72073EC9eDDd5cFD8a0;
  address public AccountingJob_Address = 0xC687f1Bcc95be9d333aB4e8196Fd5920f2cf2B5A;
  address public LiquidationJob_Address = 0x93de8CBD2C4D4A3101EE602f43232A1f5acb8CaC;
  address public OracleJob_Address = 0x8884f9CEB0cFf1475E1481ACe8D209283BDFBED3;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x19440ddD5F69a97fF182453382a99f2C0C8d7182;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x4A7Ca2158B7bB7d82297fb87C65B1A0a75256179;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x44d5C5E776D772Cb3928930C7f3977468e6718B6;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xa614a44c3b33900Be55c716A484198b6eA286D9b;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xFa545891b7b3859DD208b040C9C7B108B013588E;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xfEa9E06666B24628C02297535F0FB737476177fc;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x79Ce31EaC9F0865DE511715288186A8d98fC041B;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0xc59793CF43aD75a66469B617137DE51d796375D9;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0xf57A2A46367b2B03378438056cc84D35e8faC727;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0xC0bfF17721d27e3b31E97A1254058CD3cA5db5B9;
  address public Vault721_Address = 0xDA0dB6700D876aDE33B76914eFeAfC6BbEba6892;
  address public ODSafeManager_Address = 0x1c189b4eB039BCb8E08c7bbc8dcaAf59Cb6fB65b;
  address public NFTRenderer_Address = 0x5A5E5Db6285E658E6378bf7D09C744dEed0B5F2F;
  address public BasicActions_Address = 0xBc152eA59C71525e452AAb70D58f00630125C932;
  address public DebtBidActions_Address = 0x3D16dC2E419150297128780F0079eB6520033802;
  address public SurplusBidActions_Address = 0x9B9F1FfD8a82957Cfdad9d38AB98711d940D19E3;
  address public CollateralBidActions_Address = 0x6E833C9B729080933EF4661f0AEE11fa210967b0;
  address public PostSettlementSurplusBidActions_Address = 0xc5588f2C9ccB79eF793Ffa801601E3c4B17bd18F;
  address public GlobalSettlementActions_Address = 0xE821ECB133968BD3159BEF1b818B896D4fAe8eaC;
  address public RewardedActions_Address = 0x3fe23154233f178B5269e17b3A488CcdcDc5e42E;
}
