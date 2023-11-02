// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract SepoliaContracts {
  address public ChainlinkRelayerFactory_Address = 0x3fff8D2ce36BB6E578C8621013D30E8b3C4a8690;
  address public CamelotRelayerFactory_Address = 0xc124E36fa145A529d318F18038DFD1f3f0DF0179;
  address public DenominatedOracleFactory_Address = 0xc44182c35dA6d8319F3681b096B4F0173Ff70918;
  address public DelayedOracleFactory_Address = 0xeF1ef23EC091C942efA15a609C2F93Da898C5474;
  address public MintableVoteERC20_Address = 0x7Ff1f29BbFee60cFC4f004E9C8B58b57Ff003b3a;
  address public MintableERC20_WSTETH_Address = 0x93b19315A575532907DeB0FA63Bbd74972934784;
  address public MintableERC20_CBETH_Address = 0x11afeD730373251392b4bA3D146a334196998201;
  address public MintableERC20_RETH_Address = 0xfaB4E79F883620CE5F9d65F4f760FF706475BFca;
  address public MintableERC20_MAGIC_Address = 0x0F97Fc4b35b1C3c8c9fd6E723ebed6C267e6E2dd;
  address public DenominatedOracleChild_12_Address = 0xC15B7Bd08d7FE4553f663085FDDe5C9953359E3E;
  address public DenominatedOracleChild_14_Address = 0xACF0d145c99D5538963b806F17B25a3539E48Ecf;
  address public DenominatedOracleChild_16_Address = 0x2cAE16a838D61b5C751703132c76B69b5A1b562f;
  address public DelayedOracleChild_ARB_Address = 0x786B9E108263836E77acE4ac1231993f205b3BA2;
  address public DelayedOracleChild_WSTETH_Address = 0x485AbEF546A419a2b8B58B8127EC91f8Cc27d1D2;
  address public DelayedOracleChild_CBETH_Address = 0xccf180F3b4C7af1ee7e28035E2682A86b41e1Bed;
  address public DelayedOracleChild_RETH_Address = 0x98F8580B572f0604bD5B5E48c200065a4889ba61;
  address public DelayedOracleChild_MAGIC_Address = 0xc6d884Ec4C44D7F2B2041E012c429586a4ec1025;
  address public SystemCoin_Address = 0x94beB5fC16824338Eaa538c3c857D7f7fFf4B2Ce;
  address public ProtocolToken_Address = 0x22d953bc460246199a02A4c6C2dAA929335645d0;
  address public TimelockController_Address = 0x136b4402EE09ceC0e74D8aFf253d7d5DF39Bc9F4;
  address public ODGovernor_Address = 0x56a775aeD19836ba3C6db8155dF935d38dE3aD1A;
  address public SAFEEngine_Address = 0x30fdA32a673Af230D69cb4A11a6125D7E7E4c11D;
  address public OracleRelayer_Address = 0x9978BBC228B5dAf625315a4A7696f0f0D3930fDa;
  address public SurplusAuctionHouse_Address = 0x0eFe9B7aF21C8d345fff787082bbB5fc7B07BA82;
  address public DebtAuctionHouse_Address = 0x750ecadB0086F28e541f09eF11a759a5548E97f9;
  address public AccountingEngine_Address = 0x62c7CAE5c017016BEd5f404FD23D43a097f1d9Ba;
  address public LiquidationEngine_Address = 0xd99Ea0A9566d7e5d7e3bB504E7Ea5851dD1BF35f;
  address public CollateralAuctionHouseFactory_Address = 0x56Cae2E66D0Dd4C0e6f1944B82F3C082DCCe41EF;
  address public CoinJoin_Address = 0x266358F318D9b331Ba06cabb1f2A2211FE2BFF44;
  address public CollateralJoinFactory_Address = 0x8E68B53d0c3d3f4A9bDffD87782949041395019C;
  address public TaxCollector_Address = 0xFefAd2d690895604c8588e4d5bEE31261D06A620;
  address public StabilityFeeTreasury_Address = 0x8b68dda01E3c17edeb2fb03c6e390D25b906f8A2;
  address public GlobalSettlement_Address = 0x5e6F4CF324cf9f8Dbb27f4E9Abb2d00f8000Ed27;
  address public PostSettlementSurplusAuctionHouse_Address = 0x03355b951eD8936902eF21073A1c370E9d9Ac432;
  address public SettlementSurplusAuctioneer_Address = 0x1D6AC552B5f642A82dbB1e2697a0c1fa9585e02d;
  address public PIDController_Address = 0xfBF482CEdA400487aa740f602A1f51431aA8a4bc;
  address public PIDRateSetter_Address = 0x39192F857b0909ddC4d5B5272383C3c0b43a3967;
  address public AccountingJob_Address = 0x3D65B41898dB1504C78497A0f4FAe7a926355A5B;
  address public LiquidationJob_Address = 0x08D43780b55F31bAeE80199Bef527C9BeF4D5A28;
  address public OracleJob_Address = 0xC4813f7ca4b73A94b3077D5bADBDca1be1222735;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x5900EB92788168A8Fa518461652E889f2caBA199;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x7A8152bb519b399e85d446fFe2F432D75AEA6bf9;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xE0dF883Bc3a60Ef8e5522d7B5fE03ee2E5e4e31b;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x9d71cff8e3E2B0DC53983f9E3F38142EE99F8AB8;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xC40e96b01f526943596bd57854DAD4285878B989;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x56c04D90766bf64426037680d6bC79fEdba47E79;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x165b9CcB20cc313131c0152450dB91a7ee14E21e;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x88A755ee64e48A3dd239D6d0989D1e27E518ABE8;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0x05f8230CD0C85c43d9a7eDf26532F39B9D7E1896;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0x7eeF092e0e89d46986C987Dfb89AA306fc2374d0;
  address public Vault721_Address = 0x677Bd90AB6A27552D0744a0Af196DA127f014656;
  address public ODSafeManager_Address = 0xA3EF1c4ef0FDC10501C6F907b004Be3A5905be65;
  address public NFTRenderer_Address = 0x3319c348323aE1FDDA7b33995049f757A78fEDc3;
  address public BasicActions_Address = 0xeE34Cda23dAF9C92D417379dc258825311420bb2;
  address public DebtBidActions_Address = 0xe98882f63F1d1F749f627Ef2BA4D86B3c597Cb59;
  address public SurplusBidActions_Address = 0xb4Efb9a37f0af1b7316f2e4df52A8eB541306263;
  address public CollateralBidActions_Address = 0xEbAB30335CB9D05B3edC9CFb38b7663f7047da4A;
  address public PostSettlementSurplusBidActions_Address = 0x3BC35240184d6ddd63d189fEa5328deA0906FD7C;
  address public GlobalSettlementActions_Address = 0x9fD3826e3C89EE7f2808D877117A55d732EBa477;
  address public RewardedActions_Address = 0x2A2C3C71107E390FDB0862d835B638bfC7064c50;
}
