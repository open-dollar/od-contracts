// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0x7Ab5ae9512284fcdE1eB550BE8f9854B4E425702;
  address public DenominatedOracleFactory_Address = 0x34688c002Af519fbEf122b43B6099802A12AbE82;
  address public DelayedOracleFactory_Address = 0x58B3E7BA79FeFf7Fa7dd9d15f861FF19eDa98D8C;
  address public MintableVoteERC20_Address = 0x998D98e9480A8f52A5252Faf316d129765773294;
  address public MintableERC20_WSTETH_Address = 0xa00F03Ea2d0a6e4961CaAFcA61A78334049c1848;
  address public MintableERC20_CBETH_Address = 0x884086466e192C53BbeebEd0024B66d58C49930A;
  address public MintableERC20_RETH_Address = 0x0B36Ef2cb78859C20c8C1380CeAdB75043aA92b3;
  address public DenominatedOracleChild_10_Address = 0xd5e6B7d26ea0827f8F1731DE95F8424B385F126A;
  address public DenominatedOracleChild_12_Address = 0x7EEbFe0abbe5Ab99605274b77a142DF0AE22D80A;
  address public DenominatedOracleChild_14_Address = 0xc3AEA9F412219E39D7fbd56963929d6E64c69cF3;
  address public DelayedOracleChild_15_Address = 0x4b5Cd4b11607c1C68897d946fCDF10EdE6766BAe;
  address public DelayedOracleChild_16_Address = 0x0B9088Ac4dB0A1DB0D416A0F7837De2CE1880530;
  address public DelayedOracleChild_17_Address = 0x03402EEeE5BFEbE5c09c13Ef1C490f6aE05EF48a;
  address public DelayedOracleChild_18_Address = 0x6Ce6feC38AE602F1C4f54C5dfe3Efa3ba0D6350f;
  address public SystemCoin_Address = 0x60e09dB8212008106601646929360D20eFC4BE33;
  address public ProtocolToken_Address = 0x1e86fCe4d102A5924A9EF503f772fCA162Af2067;
  address public TimelockController_Address = 0x21432F2F86d056D1F4Ee99eC81758042C9588D03;
  address public ODGovernor_Address = 0x85f93384BAd10d7751Fcc3bBD8F8710db3190700;
  address public SAFEEngine_Address = 0x17975FB494576ae89D627F904Ec723B87c7C35c8;
  address public OracleRelayer_Address = 0x1C9f974DF781C6EB3764F21Fe961ba38305213df;
  address public SurplusAuctionHouse_Address = 0xC138B397Be84Ec53E2654eEf1D0D63355E459791;
  address public DebtAuctionHouse_Address = 0xa513902CE47191a5D4b63deFBa4f337347C512BE;
  address public AccountingEngine_Address = 0x3fb8D607A42B3c4536a7ffB8786639BfBd5cd9c0;
  address public LiquidationEngine_Address = 0x0740BFEeAEb3c8a7b8718A4F3B20618568cDF621;
  address public CollateralAuctionHouseFactory_Address = 0xDCc1fAB7b7B33dCe9b7748B7572F07fac59B0956;
  address public CoinJoin_Address = 0xE97166C46816d48B2aFFCfFf704B962E88fd0abE;
  address public CollateralJoinFactory_Address = 0xC5123B98c3A0aa1a4F9390BCf76f7B9D775a5687;
  address public TaxCollector_Address = 0x511930A41fae024714948b700764394CB759B72f;
  address public StabilityFeeTreasury_Address = 0x54c53FB74C17a2a1B28377C2C2b11D0351367eE0;
  address public GlobalSettlement_Address = 0x9090EcAeBa8d113e49ad8Ca83Bf9FB516C723885;
  address public PostSettlementSurplusAuctionHouse_Address = 0xa98b9f2D8426DF201F4732947635C52841b04a25;
  address public SettlementSurplusAuctioneer_Address = 0x394b07B5c9A19a553E49eC95A2aF1c4a56eA634B;
  address public PIDController_Address = 0x70401A4AB04A90043BD419f56CC36B77D0587C30;
  address public PIDRateSetter_Address = 0x4C70a29A4be0954eE358f03C18BecCb888549c01;
  address public AccountingJob_Address = 0xBc8f87CA68de19edED1c96f2789A4967F9e78E65;
  address public LiquidationJob_Address = 0x5671CE66F356e67f291643911c3AC1269A5B3f69;
  address public OracleJob_Address = 0xB6b46DfD045134249e8DaC98a188e0C23B56A0b8;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x455E2C5E32432B84Dd00E5530eB3B2acbb42D392;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xF21A15aB73AAB39519384F2bB37934ab2D2B8FF1;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xD15d9C3010E3cb592cBaaa0596D4F5698ffF1399;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xFeCc9Afd11d36132d688387956C9E6875A1c057a;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xC5E1a17F63041ef5d08dB6Fdc84e70fBb91FF915;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xA6Ae7793C86317467FC304E63f9EF0B17350913E;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xdA401b81218F85C5E2Bd0bfd2129662BCB238AEa;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0xbB5F9af59b7340f69590709CbF04882Eed734324;
  address public Vault721_Address = 0xE47E83CA6Be588834f4d6108d092590b7Bd61463;
  address public ODSafeManager_Address = 0x8dA47DD12384f3A0c711E0cCb8Ac60D50d0e8cC8;
  address public NFTRenderer_Address = 0x732cc7c39e80d553513174Dc6F3AD6a4A107957F;
  address public BasicActions_Address = 0x143E8C6D4114Ea49292D4183bB7df2382A58FC28;
  address public DebtBidActions_Address = 0xa9186cf932e4e05b4606d107361Ae7b6651AF1b7;
  address public SurplusBidActions_Address = 0x31a46feD168ECb9DE7d87E543Ba2e8DD101ad0a0;
  address public CollateralBidActions_Address = 0x49A60936D52A63d9069DD667B8c84E4274d0A0B6;
  address public PostSettlementSurplusBidActions_Address = 0xfDE447BFa4e774606a6b0c73268Bc515a12c09c7;
  address public GlobalSettlementActions_Address = 0x977E2F3aA628f7676d685A3AFe2df48c51C9949a;
  address public RewardedActions_Address = 0x8647AC3a1270c746130418010A368449d1944A82;
}
