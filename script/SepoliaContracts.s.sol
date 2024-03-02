// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract SepoliaContracts {
  address public SystemCoin_Address = 0x36D197e6145B37b8E2c6Ed20B568860835b55584;
  address public ProtocolToken_Address = 0x3b22b14ecB163B8d9eaBE8565d9b4c86B7cC84eC;
  address public ChainlinkRelayerFactory_Address = 0x4394526A535766545597D966E21E65F976331943;
  address public DenominatedOracleFactory_Address = 0x19a82BF99521A72304B40445F6266D317b39F999;
  address public DelayedOracleFactory_Address = 0x171B9059e0939161644611607f870650Ab44152c;
  address public MintableVoteERC20_Address = 0xDEF0fB3BF49E1d20F7679753F4215ADD081BBf68;
  address public MintableERC20_WSTETH_Address = 0x5Ae92E2cBce39b74f149B7dA16d863382397d4a7;
  address public MintableERC20_CBETH_Address = 0x5884954cfC2B2344DEE7DB8b2bb1b19Bf9b770cd;
  address public MintableERC20_RETH_Address = 0x3246B6d95FAFA609C5D124576364Cf9356b65988;
  address public ChainlinkRelayerChild_8_Address = 0xF7f8893424F20bBC78C78aAD2015b1341a944F18;
  address public DenominatedOracleChild_10_Address = 0x009C134A186FAd21D29917237Af274Fa016cba3a;
  address public DenominatedOracleChild_12_Address = 0x3feD31Aa40AEb90fBC097Da68Bf7F238F9A488c7;
  address public DelayedOracleChild_ARB_Address = 0x6782987fA79E0cF8b29AA97DF68Cda0Cb710141c;
  address public DelayedOracleChild_WSTETH_Address = 0x319ba9Ea25Fe608dD395bdcf500f3689d0b5BfaB;
  address public DelayedOracleChild_CBETH_Address = 0x7c323DB9a77902AF7E6D88FeFd6Da11C6A7f75E3;
  address public DelayedOracleChild_RETH_Address = 0xb81D8C98d015AFd7a93704a44c2AA07144b61b90;
  address public TimelockController_Address = 0xAa1a2c772EB12a7618954CfAEF404Aa70682e771;
  address public ODGovernor_Address = 0x007D6E9Fa42147fc107d732f2eD74d2cbC5238BB;
  address public SAFEEngine_Address = 0xda29B91e16d649e7B6F60A70102B288C4202a73D;
  address public OracleRelayer_Address = 0x1e9D2b79c6Ec39b7c6BF4DA3f51a609C5d929464;
  address public SurplusAuctionHouse_Address = 0xd012b20C84Caf5266057c6DF69Eee81Af7136bFF;
  address public DebtAuctionHouse_Address = 0xCEaC6a8Ea36a0b3059C74B1f5390e46dc7B35067;
  address public AccountingEngine_Address = 0x22c89791FAac0c93c5dabCe08fcA49010eA02f7a;
  address public LiquidationEngine_Address = 0x76d90151Ae5bD1Fc5e09F5A02A42824E26a323DB;
  address public CollateralAuctionHouseFactory_Address = 0x0FeeF854DC426b5d61dD11AE74c3E43d2eaba340;
  address public CoinJoin_Address = 0x93544B224AB94F2b568CaeD5A074f4217fC782c7;
  address public CollateralJoinFactory_Address = 0xb4793C576Cc7163cDa4463804Dde543b2d85bF8E;
  address public TaxCollector_Address = 0x8D5978b4bf95407AeA0909440a1837ac531c586B;
  address public StabilityFeeTreasury_Address = 0x047c081F604e677403de7aFb38bD8B0a5b1cDD50;
  address public GlobalSettlement_Address = 0xB021185694795C4c0fc2529d64185c49B01aBb79;
  address public PostSettlementSurplusAuctionHouse_Address = 0x1b6Cc7354e1D594647E6EE87114145B50145CcAa;
  address public SettlementSurplusAuctioneer_Address = 0x70cd27026d487deeFf817b3ca2A2aC9a8F30E62B;
  address public PIDController_Address = 0xBD2fcEC8838Fab2C31BE80583f666664Ef82867A;
  address public PIDRateSetter_Address = 0xa3Dd8BFf2a2c371DD8b8A1a3C5bFA85a76D7e161;
  address public AccountingJob_Address = 0x9F097D43Cb9E2f2056b2625Fcd8645ca73d08984;
  address public LiquidationJob_Address = 0x97d8dA5c2CC50ec53fC16C7457692D68871E3aCF;
  address public OracleJob_Address = 0x975aB5F04B6B43c2c3F74097fDDa99af52a90989;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x5C65890F15d9d78A7c0F7e83ab62a87ed0BD4cee;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x16FF8Eb3b8144E00fd9Aa958f02b2Fbf3814c8F7;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x52400D3AEB82b0923898D918be51439A9198D980;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x2Cd3BF07a4d434a78EA2d2fd3BD97Ffd1643991e;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xA1f2739a44c42A3DdE6d6e21852b77b0F90790f4;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xa752610Dc28602b6608Ff3F1eFc34e47a8909e26;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x707AD742ce9064bab6B54670Be90866987596eFa;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0xfCbBBF6Ed1f93cFA5794C9952444fdef21AEcEfE;
  address public Vault721_Address = 0xa602c0cFf8028Dd4c99fbC5e85cF0c083C5b991A;
  address public ODSafeManager_Address = 0x8ca7D88eaFB6f666997Ca0F62Beddd8A09a62910;
  address public NFTRenderer_Address = 0x53c239d164BAd9A5b979cb2039f07cb7573409D5;
  address public BasicActions_Address = 0x60487E0a0eFbfbD30908b03ea6b7833E2520604F;
  address public DebtBidActions_Address = 0xA5969D1D5DB3D9456B062b55b52244108130E05D;
  address public SurplusBidActions_Address = 0xaA2d962926c4a09FdB6323a46400A2d848C9A97f;
  address public CollateralBidActions_Address = 0xf8D494A026075Ccc3FC62dED62cD821F1320c300;
  address public PostSettlementSurplusBidActions_Address = 0xfF5b17F3D1E3329aB50677110A290f99F39af4c5;
  address public GlobalSettlementActions_Address = 0x2c281AF052959073ad1B9d9Cd437aEFf6114569F;
  address public RewardedActions_Address = 0x27E1A17629645f5F7cAF9733E55aA6b2207bea2F;
}
