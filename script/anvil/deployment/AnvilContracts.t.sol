// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0xdFdE6B33f13de2CA1A75A6F7169f50541B14f75b;
  address public DenominatedOracleFactory_Address = 0xaC9fCBA56E42d5960f813B9D0387F3D3bC003338;
  address public DelayedOracleFactory_Address = 0x38A70c040CA5F5439ad52d0e821063b0EC0B52b6;
  address public MintableVoteERC20_Address = 0xf090f16dEc8b6D24082Edd25B1C8D26f2bC86128;
  address public MintableERC20_WSTETH_Address = 0xd9140951d8aE6E5F625a02F5908535e16e3af964;
  address public MintableERC20_CBETH_Address = 0x56D13Eb21a625EdA8438F55DF2C31dC3632034f5;
  address public MintableERC20_RETH_Address = 0xE8addD62feD354203d079926a8e563BC1A7FE81e;
  address public DenominatedOracleChild_10_Address = 0x2c8ECa0E7f283AdF32524f3065440C2902C31EF7;
  address public DenominatedOracleChild_12_Address = 0x077383f6B364022f55Abc18690e2e7737c70eba1;
  address public DenominatedOracleChild_14_Address = 0x5809067c9d645Cb4793b9076bF5E96f61D8a755b;
  address public DelayedOracleChild_15_Address = 0x02B7d5Ce8779587B7C33a3c31c5b8280a446190C;
  address public DelayedOracleChild_16_Address = 0x313E0C0f29e1063E6cD8f1eB66bdcb9EF360F362;
  address public DelayedOracleChild_17_Address = 0x340Dbc7898bb0993C267A30406EFe7674aB5b2FF;
  address public DelayedOracleChild_18_Address = 0x9Bc71bE9D44dee9A1F7Fb02E6377Abb6fd016f65;
  address public SystemCoin_Address = 0x139e1D41943ee15dDe4DF876f9d0E7F85e26660A;
  address public ProtocolToken_Address = 0xAdE429ba898c34722e722415D722A70a297cE3a2;
  address public TimelockController_Address = 0x82EdA215Fa92B45a3a76837C65Ab862b6C7564a8;
  address public ODGovernor_Address = 0x87006e75a5B6bE9D1bbF61AC8Cd84f05D9140589;
  address public SAFEEngine_Address = 0xc9952Fc93Fa9bE383ccB39008c786b9f94eAc95d;
  address public OracleRelayer_Address = 0xDde063eBe8E85D666AD99f731B4Dbf8C98F29708;
  address public SurplusAuctionHouse_Address = 0xD5724171C2b7f0AA717a324626050BD05767e2C6;
  address public DebtAuctionHouse_Address = 0x70eE76691Bdd9696552AF8d4fd634b3cF79DD529;
  address public AccountingEngine_Address = 0x8B190573374637f144AC8D37375d97fd84cBD3a0;
  address public LiquidationEngine_Address = 0x9385556B571ab92bf6dC9a0DbD75429Dd4d56F91;
  address public CollateralAuctionHouseFactory_Address = 0x162700d1613DfEC978032A909DE02643bC55df1A;
  address public CoinJoin_Address = 0x67aD6EA566BA6B0fC52e97Bc25CE46120fdAc04c;
  address public CollateralJoinFactory_Address = 0x114e375B6FCC6d6fCb68c7A1d407E652C54F25FB;
  address public TaxCollector_Address = 0xcD0048A5628B37B8f743cC2FeA18817A29e97270;
  address public StabilityFeeTreasury_Address = 0x976C214741b4657bd99DFD38a5c0E3ac5C99D903;
  address public GlobalSettlement_Address = 0x6A59CC73e334b018C9922793d96Df84B538E6fD5;
  address public PostSettlementSurplusAuctionHouse_Address = 0xC1e0A9DB9eA830c52603798481045688c8AE99C2;
  address public SettlementSurplusAuctioneer_Address = 0x683d9CDD3239E0e01E8dC6315fA50AD92aB71D2d;
  address public PIDController_Address = 0x22a9B82A6c3D2BFB68F324B2e8367f346Dd6f32a;
  address public PIDRateSetter_Address = 0x547382C0D1b23f707918D3c83A77317B71Aa8470;
  address public AccountingJob_Address = 0x79E8AB29Ff79805025c9462a2f2F12e9A496f81d;
  address public LiquidationJob_Address = 0x0Dd99d9f56A14E9D53b2DdC62D9f0bAbe806647A;
  address public OracleJob_Address = 0xeAd789bd8Ce8b9E94F5D0FCa99F8787c7e758817;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0xB26dD3781CE737f266bd14f732879F493f809233;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xa5F4145D7d031c96c0140596f0020Fe4666D8170;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x7eA9EBfdc9044b79919FB410cEB657Ef6F2bAc89;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x816dA8Baf61f31EA8AaFC64dEaa5Aba1dBBF959A;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xFC38C8957840882e0054B9640608257eD13a4325;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xb8Fa0c3FFA6Cd36c1074187b19C6F98C5120F62a;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x1876908Fd207680dAe0d4CD9Ef52C724b05244fB;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x145Bc8d5beC909b361580884dE867eD518241030;
  address public Vault721_Address = 0x33E45b187da34826aBCEDA1039231Be46f1b05Af;
  address public ODSafeManager_Address = 0xA21DDc1f17dF41589BC6A5209292AED2dF61Cc94;
  address public NFTRenderer_Address = 0x2A590C461Db46bca129E8dBe5C3998A8fF402e76;
  address public BasicActions_Address = 0x158d291D8b47F056751cfF47d1eEcd19FDF9B6f8;
  address public DebtBidActions_Address = 0x2F54D1563963fC04770E85AF819c89Dc807f6a06;
  address public SurplusBidActions_Address = 0xF342E904702b1D021F03f519D6D9614916b03f37;
  address public CollateralBidActions_Address = 0x9849832a1d8274aaeDb1112ad9686413461e7101;
  address public PostSettlementSurplusBidActions_Address = 0xa4E00CB342B36eC9fDc4B50b3d527c3643D4C49e;
  address public GlobalSettlementActions_Address = 0x8ac5eE52F70AE01dB914bE459D8B3d50126fd6aE;
  address public RewardedActions_Address = 0x325c8Df4CFb5B068675AFF8f62aA668D1dEc3C4B;
}
