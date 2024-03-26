// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0x9BcC604D4381C5b0Ad12Ff3Bf32bEdE063416BC7;
  address public DenominatedOracleFactory_Address = 0x63fea6E447F120B8Faf85B53cdaD8348e645D80E;
  address public DelayedOracleFactory_Address = 0xdFdE6B33f13de2CA1A75A6F7169f50541B14f75b;
  address public MintableVoteERC20_Address = 0x38A70c040CA5F5439ad52d0e821063b0EC0B52b6;
  address public MintableERC20_WSTETH_Address = 0x54B8d8E2455946f2A5B8982283f2359812e815ce;
  address public MintableERC20_CBETH_Address = 0xf090f16dEc8b6D24082Edd25B1C8D26f2bC86128;
  address public MintableERC20_RETH_Address = 0xd9140951d8aE6E5F625a02F5908535e16e3af964;
  address public DenominatedOracleChild_10_Address = 0x0Ccf6a85510fc2ECD2DB37EF2C886c787D6C4A1d;
  address public DenominatedOracleChild_12_Address = 0xc1581652295cdcFd10B24858fA5984c4FAdb0bD0;
  address public DenominatedOracleChild_14_Address = 0xb8677Cb640ab9bCcb48D9340Ab6010302169bAdA;
  address public DelayedOracleChild_15_Address = 0x477044170B5AB7DdF4d688e6C6Da6Cc5465338c4;
  address public DelayedOracleChild_16_Address = 0xd7bD70ae52258ee5f7a5853a0D42995030874355;
  address public DelayedOracleChild_17_Address = 0xb42A9e6a365a0113DF837D655FA2015ab2825864;
  address public DelayedOracleChild_18_Address = 0xB8c8fF5652494f22f166802DcBB72a5ceAAcEd84;
  address public SystemCoin_Address = 0xFE5f411481565fbF70D8D33D992C78196E014b90;
  address public ProtocolToken_Address = 0xD6b040736e948621c5b6E0a494473c47a6113eA8;
  address public TimelockController_Address = 0x7B4f352Cd40114f12e82fC675b5BA8C7582FC513;
  address public ODGovernor_Address = 0xcE0066b1008237625dDDBE4a751827de037E53D2;
  address public SAFEEngine_Address = 0x8fC8CFB7f7362E44E472c690A6e025B80E406458;
  address public OracleRelayer_Address = 0xC7143d5bA86553C06f5730c8dC9f8187a621A8D4;
  address public SurplusAuctionHouse_Address = 0x359570B3a0437805D0a71457D61AD26a28cAC9A2;
  address public DebtAuctionHouse_Address = 0xc9952Fc93Fa9bE383ccB39008c786b9f94eAc95d;
  address public AccountingEngine_Address = 0xDde063eBe8E85D666AD99f731B4Dbf8C98F29708;
  address public LiquidationEngine_Address = 0xD5724171C2b7f0AA717a324626050BD05767e2C6;
  address public CollateralAuctionHouseFactory_Address = 0x70eE76691Bdd9696552AF8d4fd634b3cF79DD529;
  address public CoinJoin_Address = 0x8B190573374637f144AC8D37375d97fd84cBD3a0;
  address public CollateralJoinFactory_Address = 0x9385556B571ab92bf6dC9a0DbD75429Dd4d56F91;
  address public TaxCollector_Address = 0x162700d1613DfEC978032A909DE02643bC55df1A;
  address public StabilityFeeTreasury_Address = 0x67aD6EA566BA6B0fC52e97Bc25CE46120fdAc04c;
  address public GlobalSettlement_Address = 0x0aec7c174554AF8aEc3680BB58431F6618311510;
  address public PostSettlementSurplusAuctionHouse_Address = 0x8e264821AFa98DD104eEcfcfa7FD9f8D8B320adA;
  address public SettlementSurplusAuctioneer_Address = 0x871ACbEabBaf8Bed65c22ba7132beCFaBf8c27B5;
  address public PIDController_Address = 0x01E21d7B8c39dc4C764c19b308Bd8b14B1ba139E;
  address public PIDRateSetter_Address = 0x3C1Cb427D20F15563aDa8C249E71db76d7183B6c;
  address public AccountingJob_Address = 0x7C8BaafA542c57fF9B2B90612bf8aB9E86e22C09;
  address public LiquidationJob_Address = 0x0a17FabeA4633ce714F1Fa4a2dcA62C3bAc4758d;
  address public OracleJob_Address = 0x5e6CB7E728E1C320855587E1D9C6F7972ebdD6D5;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0xEDD892A79e50aA5FD11A43379d37851b49aF3320;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xcF25c70D942A2dB6A6d11a897BE47d3D9153aB58;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x5486626ef43f5b9ef34180FC872444BF46feA2A7;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x90d555f0f44F8AC7Ae1AF1f354e7B51c7f63F163;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x7BCad650Ec28c57B87c86182c0DC39f099fd7F08;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xe52Dde8EB44762507B3451B94812971B45304891;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x27590a9563010CEe91dd625Cd2123037861eB63a;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0xb851B3f3cd064F13cEA47602423A30DE36aA7847;
  address public Vault721_Address = 0x9c65f85425c619A6cB6D29fF8d57ef696323d188;
  address public ODSafeManager_Address = 0x33E45b187da34826aBCEDA1039231Be46f1b05Af;
  address public NFTRenderer_Address = 0x0c626FC4A447b01554518550e30600136864640B;
  address public BasicActions_Address = 0xA21DDc1f17dF41589BC6A5209292AED2dF61Cc94;
  address public DebtBidActions_Address = 0x2A590C461Db46bca129E8dBe5C3998A8fF402e76;
  address public SurplusBidActions_Address = 0x158d291D8b47F056751cfF47d1eEcd19FDF9B6f8;
  address public CollateralBidActions_Address = 0x2F54D1563963fC04770E85AF819c89Dc807f6a06;
  address public PostSettlementSurplusBidActions_Address = 0xF342E904702b1D021F03f519D6D9614916b03f37;
  address public GlobalSettlementActions_Address = 0x9849832a1d8274aaeDb1112ad9686413461e7101;
  address public RewardedActions_Address = 0xa4E00CB342B36eC9fDc4B50b3d527c3643D4C49e;
}
