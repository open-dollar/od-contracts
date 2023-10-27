// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x04072401689Da5AE760daa3d90C425dbc36Ae53A;
  address public UniV3RelayerFactory_Address = 0xffb2CAe67b5e036aa76eD6C9E0891B313136BA97;
  address public CamelotRelayerFactory_Address = 0x49B92c921A04eAB92C7e741435fAa4580FCd1db1;
  address public DenominatedOracleFactory_Address = 0xE7682F944b6d5329332a490d4c4cA875a13D138b;
  address public DelayedOracleFactory_Address = 0x626410a6974f929Fe87025ed86347F314aec3A2a;
  address public MintableVoteERC20_Address = 0x2D584f0A2524347833b803C908cc748e6aF529d8;
  address public MintableERC20_WSTETH_Address = 0x9B7149c48fed455f45B4E095fC5e0dEBa3B15A06;
  address public MintableERC20_CBETH_Address = 0x0445D8620E577DAE2d9221348fF5120F4750679a;
  address public MintableERC20_RETH_Address = 0xD011fE48E49e352FEa4C855f4352988072C9fb57;
  address public MintableERC20_MAGIC_Address = 0xF848AD3cd8886980F2D8bA9f63d76Ff19AFa9580;
  address public ChainlinkRelayerChild_11_Address = 0xDDe8ef155B974f6693990748ec861deb152CbBF5;
  address public DenominatedOracleChild_13_Address = 0x0009Cade5dd40379fB17B030098e74F55035300e;
  address public DenominatedOracleChild_15_Address = 0x7Ab2e3a2383559168C8a22da9058666f28303B76;
  address public DenominatedOracleChild_17_Address = 0x137C828aF26fC0ADA8B2F7e8A6d018effC5Bb7E6;
  address public DelayedOracleChild_ARB_Address = 0xc45e7d55a7E493Cfb3f213b3f5b16d290192a539;
  address public DelayedOracleChild_WSTETH_Address = 0xfDa92B95d9c593CE2cB94412c950c5886C5CB7cf;
  address public DelayedOracleChild_CBETH_Address = 0x4e0c226E0d1eafD2A3dcB48410A24E42fD99865f;
  address public DelayedOracleChild_RETH_Address = 0x51069F055f488D650e464307323f8dC5857142a2;
  address public DelayedOracleChild_MAGIC_Address = 0x46aBc5476B11C3b873F1E80a9F742ac241Fbc14e;
  address public SystemCoin_Address = 0x08D6842A82d244f89D7745e54cB5376B31bb7104;
  address public ProtocolToken_Address = 0xab893fCB828ba2171006B69da59d1f76930513E5;
  address public TimelockController_Address = 0xEa8749d72D92F7BCFAD36f055509c03333967401;
  address public ODGovernor_Address = 0xe0F26944828bF18EAdD26F45FA2A7Da3C21D5Ae7;
  address public SAFEEngine_Address = 0x20dce3A3EEd5cD3691B5C71d358da373cB32f93A;
  address public OracleRelayer_Address = 0x59610FFe05326BCEf7e3DB4a741Ae96FA49195B3;
  address public SurplusAuctionHouse_Address = 0x7Ce17c750c19e00cE81Eb069316Bd17Ba4ee122F;
  address public DebtAuctionHouse_Address = 0x349787F124caE4c5d2829F081Cc2fFF8d076f20c;
  address public AccountingEngine_Address = 0x91531DBA021ed58Ca1af82E3Db840553B7895cCa;
  address public LiquidationEngine_Address = 0x4cFE7fD7EB80D03D5fe46fC1d4a8aF6888127B03;
  address public CollateralAuctionHouseFactory_Address = 0x3DDA23eF12b6659223884a47861ee86985D029a2;
  address public CoinJoin_Address = 0xfDe630ADF6d4Db601d63E4eFD36ebf161d27aFE9;
  address public CollateralJoinFactory_Address = 0x7641983cA4925b03f8A24fDBAaa42c03e2B12003;
  address public TaxCollector_Address = 0x0F43bE6E6A2ed89db7fC3Ba853A59795540a3af7;
  address public StabilityFeeTreasury_Address = 0xf5cA8EB201958dFF5f07Cfacbbb4B6C930F5472d;
  address public GlobalSettlement_Address = 0xB3c7a1A5cd839b5DfE16D8dF27E4C1BAf367a1C2;
  address public PostSettlementSurplusAuctionHouse_Address = 0xAd39b025BB2e6CD3dF135b2db12C77B364A09063;
  address public SettlementSurplusAuctioneer_Address = 0xd81108779C57B188f6547Bc7D23fC03828d10f70;
  address public PIDController_Address = 0x0464879020364120eD1D2FacC6132d780d24823d;
  address public PIDRateSetter_Address = 0x0eCFF6F8b143dA3ECCD8B9DD36E848F7Df1dd8A7;
  address public AccountingJob_Address = 0xDb6423A0Aa7E879Ba15c386306D21E593BC01418;
  address public LiquidationJob_Address = 0xCc0059Bb42bd9554c5aBF3504869E9bf2fE1C994;
  address public OracleJob_Address = 0xD344E36B18d41F459ACb14d8a6261D95D5897966;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x06C5B1E5211f4FA02E39cA681eD39B93264Fae92;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xD9032C6375d6d33Ad486f232a78aC6EFE4A9cDA0;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x8Bf6f847eC072a273E40616bfa03aA909D7802CC;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x7b54c04895464FFbB355f8F621f81C9fa6d5Ab6E;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x24942d0506270fa9681e5849d5bF5590fDB65299;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x39A90f5850FB0952573dA2EE7e8f7308aCd648F6;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x5aA5dF208a398D32D31De8beCd3Cf79EAbd94D8F;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x31661366c4B714724D7876a00cD2999F3C555DeC;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0xBF9D35d7f1f1C7D2580A69Bb400b5ce9466F776D;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0x52271468ECb9CA41686A3048De3161dF90426668;
  address public Vault721_Address = 0x5bf3894Bd33864128bD53545ee803280BF14205a;
  address public ODSafeManager_Address = 0x019872403C3179eab39d6f258375aF57b0102eCE;
  address public NFTRenderer_Address = 0xA86895fB19E36ACb868FB3c43dEF983D9302eDef;
  address public BasicActions_Address = 0xb4eA6d759326199F1BF41dFE0324072241ca27B1;
  address public DebtBidActions_Address = 0xAfC017b1DAB49394bc495820885A86f956812AD1;
  address public SurplusBidActions_Address = 0x4ca1ad73505063d2dd34F534a24628369336EA8a;
  address public CollateralBidActions_Address = 0x917256518fBa74f012B916ECaAC81b83AeCA4a93;
  address public PostSettlementSurplusBidActions_Address = 0xD371F53FB2A190034772Ff8adC3C76c9037b89D8;
  address public GlobalSettlementActions_Address = 0x8756f1399B878D04a76c7E6123F9C06650ED178E;
  address public RewardedActions_Address = 0x20cf2Fc70b0134e59bf37091597Fa06F6f1EB0c0;
}
