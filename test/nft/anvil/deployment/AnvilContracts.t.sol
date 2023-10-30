// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0x9D3DA37d36BB0B825CD319ed129c2872b893f538;
  address public UniV3RelayerFactory_Address = 0x59C4e2c6a6dC27c259D6d067a039c831e1ff4947;
  address public CamelotRelayerFactory_Address = 0x9d136eEa063eDE5418A6BC7bEafF009bBb6CFa70;
  address public DenominatedOracleFactory_Address = 0x687bB6c57915aa2529EfC7D2a26668855e022fAE;
  address public DelayedOracleFactory_Address = 0x49149a233de6E4cD6835971506F47EE5862289c1;
  address public MintableVoteERC20_Address = 0x30426D33a78afdb8788597D5BFaBdADc3Be95698;
  address public MintableERC20_7_Address = 0x85495222Fd7069B987Ca38C2142732EbBFb7175D;
  address public MintableERC20_8_Address = 0x3abBB0D6ad848d64c8956edC9Bf6f18aC22E1485;
  address public MintableERC20_9_Address = 0x021DBfF4A864Aa25c51F0ad2Cd73266Fde66199d;
  address public MintableERC20_10_Address = 0x4CF4dd3f71B67a7622ac250f8b10d266Dc5aEbcE;
  address public DenominatedOracleChild_13_Address = 0x13E0Ece0Fa1Ff3795947FaB553dA5DaB6c9eF470;
  address public DenominatedOracleChild_15_Address = 0x92a1E5FEd0e204969F8709D4d4A6428069E7F3be;
  address public DenominatedOracleChild_17_Address = 0xB0B7aB3C735390F59470Be18b9301362B1071a1E;
  address public DenominatedOracleChild_19_Address = 0x325a5C469e4282Fb9f6f83E98Cc466cbf486d208;
  address public DelayedOracleChild_20_Address = 0x0b545A095e837d23a74340A75798B519fA27bcbD;
  address public DelayedOracleChild_21_Address = 0x8969082A1F523F2Cb734C17557d38f97FEbaD931;
  address public DelayedOracleChild_22_Address = 0x860EC8065Ce6FCB21Eb0Cf7aC344473237408B37;
  address public DelayedOracleChild_23_Address = 0x1b310ad13998D1fC2B8A449c55Bb389933D326EE;
  address public DelayedOracleChild_24_Address = 0x668513F424DD6648aAdFE30aaF127B5e20C6f764;
  address public SystemCoin_Address = 0xce830DA8667097BB491A70da268b76a081211814;
  address public ProtocolToken_Address = 0xD5bFeBDce5c91413E41cc7B24C8402c59A344f7c;
  address public TimelockController_Address = 0x77AD263Cd578045105FBFC88A477CAd808d39Cf6;
  address public ODGovernor_Address = 0x38628490c3043E5D0bbB26d5a0a62fC77342e9d5;
  address public SAFEEngine_Address = 0x64f5219563e28EeBAAd91Ca8D31fa3b36621FD4f;
  address public OracleRelayer_Address = 0x1757a98c1333B9dc8D408b194B2279b5AFDF70Cc;
  address public SurplusAuctionHouse_Address = 0x6484EB0792c646A4827638Fc1B6F20461418eB00;
  address public DebtAuctionHouse_Address = 0xf201fFeA8447AB3d43c98Da3349e0749813C9009;
  address public AccountingEngine_Address = 0xA75E74a5109Ed8221070142D15cEBfFe9642F489;
  address public LiquidationEngine_Address = 0x26291175Fa0Ea3C8583fEdEB56805eA68289b105;
  address public CollateralAuctionHouseFactory_Address = 0x840748F7Fd3EA956E5f4c88001da5CC1ABCBc038;
  address public CoinJoin_Address = 0x1bEfE2d8417e22Da2E0432560ef9B2aB68Ab75Ad;
  address public CollateralJoinFactory_Address = 0x04f1A5b9BD82a5020C49975ceAd160E98d8B77Af;
  address public TaxCollector_Address = 0xde79380FBd39e08150adAA5C6c9dE3146f53029e;
  address public StabilityFeeTreasury_Address = 0xbFD3c8A956AFB7a9754C951D03C9aDdA7EC5d638;
  address public GlobalSettlement_Address = 0x746a48E39dC57Ff14B872B8979E20efE5E5100B1;
  address public PostSettlementSurplusAuctionHouse_Address = 0x96E303b6D807c0824E83f954784e2d6f3614f167;
  address public SettlementSurplusAuctioneer_Address = 0x9CC8B5379C40E24F374cd55973c138fff83ed214;
  address public PIDController_Address = 0x68d2Ecd85bDEbfFd075Fb6D87fFD829AD025DD5C;
  address public PIDRateSetter_Address = 0x9D3999af03458c11C78F7e6C0fAE712b455D4e33;
  address public AccountingJob_Address = 0x20Dc424c5fa468CbB1c702308F0cC9c14DA2825C;
  address public LiquidationJob_Address = 0x4653251486a57f90Ee89F9f34E098b9218659b83;
  address public OracleJob_Address = 0x89ec9355b1Bcc964e576211c8B011BD709083f8d;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x12a1e102477EB4641E26Aa03E0aB460eA290F4B9;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xA4d82217474460D3250F2Be0C8E58FDf60cd21De;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xB71167ef9d1889f8cb0Eee2f91aEBFe15CD15Bf6;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xB1FA566C031E4405Ac6d5efA14B01caAAdd75896;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x863b7cFD6D479904D46C687e975a5a434a0198d1;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xD3fA2164F9eCf544E57ACCe761D3D8115CAD1804;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x5BA0398217F8E6508937649D162f70eeA6f5D3B5;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0xADB27Ef31B5E93d68856CcA99197253a65b06AF3;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0x6885166c2c92a6D1AFEf4f0556a18004c62FaA86;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0xdbA56F85e1404Df7c9e33973851B1222D21CDF77;
  address public Vault721_Address = 0x889D9A5AF83525a2275e41464FAECcCb3337fF60;
  address public ODSafeManager_Address = 0xf274De14171Ab928A5Ec19928cE35FaD91a42B64;
  address public NFTRenderer_Address = 0xcb0A9835CDf63c84FE80Fcc59d91d7505871c98B;
  address public BasicActions_Address = 0xFD296cCDB97C605bfdE514e9810eA05f421DEBc2;
  address public DebtBidActions_Address = 0x8b9d5A75328b5F3167b04B42AD00092E7d6c485c;
  address public SurplusBidActions_Address = 0x9BcA065E19b6d630032b53A8757fB093CbEAfC1d;
  address public CollateralBidActions_Address = 0xd8A9159c111D0597AD1b475b8d7e5A217a1d1d05;
  address public PostSettlementSurplusBidActions_Address = 0xCdb63c58b907e76872474A0597C5252eDC97c883;
  address public GlobalSettlementActions_Address = 0x15BB2cc3Ea43ab2658F7AaecEb78A9d3769BE3cb;
  address public RewardedActions_Address = 0xa4d0806d597146df93796A38435ABB2a3cb96677;
}
