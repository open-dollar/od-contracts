// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0xf274De14171Ab928A5Ec19928cE35FaD91a42B64;
  address public DenominatedOracleFactory_Address = 0xcb0A9835CDf63c84FE80Fcc59d91d7505871c98B;
  address public DelayedOracleFactory_Address = 0xFD296cCDB97C605bfdE514e9810eA05f421DEBc2;
  address public MintableVoteERC20_Address = 0x9BcA065E19b6d630032b53A8757fB093CbEAfC1d;
  address public MintableERC20_WSTETH_Address = 0xd8A9159c111D0597AD1b475b8d7e5A217a1d1d05;
  address public MintableERC20_CBETH_Address = 0xCdb63c58b907e76872474A0597C5252eDC97c883;
  address public MintableERC20_RETH_Address = 0x15BB2cc3Ea43ab2658F7AaecEb78A9d3769BE3cb;
  address public DenominatedOracleChild_10_Address = 0x47EC30E62f2b2701Bf335E7bf2a68E7513DBAdF1;
  address public DenominatedOracleChild_12_Address = 0xFd25f925aa8259bc61F882B169DA1dF3a8F06cB3;
  address public DenominatedOracleChild_14_Address = 0x791B95CEaA026C995fb929F8458B7d350Ed9673c;
  address public DelayedOracleChild_15_Address = 0xf90253e98be4FE168bA259d15E86649209c89525;
  address public DelayedOracleChild_16_Address = 0xC050F6702898B5caD013cCd9458003D70399E5CF;
  address public DelayedOracleChild_17_Address = 0x334570Fad10EaE26dfEF8f7ccdF481D2C0e2861E;
  address public DelayedOracleChild_18_Address = 0x79f15Fd80eA49D2aDd55eD49AE676D43A420098a;
  address public SystemCoin_Address = 0xEb0fCBB68Ca7Ba175Dc1D3dABFD618e7a3F582F6;
  address public ProtocolToken_Address = 0xaE2abbDE6c9829141675fA0A629a675badbb0d9F;
  address public TimelockController_Address = 0xD28F3246f047Efd4059B24FA1fa587eD9fa3e77F;
  address public ODGovernor_Address = 0x15F2ea83eB97ede71d84Bd04fFF29444f6b7cd52;
  address public SAFEEngine_Address = 0xb6057e08a11da09a998985874FE2119e98dB3D5D;
  address public OracleRelayer_Address = 0xad203b3144f8c09a20532957174fc0366291643c;
  address public SurplusAuctionHouse_Address = 0x31403b1e52051883f2Ce1B1b4C89f36034e1221D;
  address public DebtAuctionHouse_Address = 0x4278C5d322aB92F1D876Dd7Bd9b44d1748b88af2;
  address public AccountingEngine_Address = 0x0D92d35D311E54aB8EEA0394d7E773Fc5144491a;
  address public LiquidationEngine_Address = 0x24EcC5E6EaA700368B8FAC259d3fBD045f695A08;
  address public CollateralAuctionHouseFactory_Address = 0x876939152C56362e17D508B9DEA77a3fDF9e4083;
  address public CoinJoin_Address = 0xD56e6F296352B03C3c3386543185E9B8c2e5Fd0b;
  address public CollateralJoinFactory_Address = 0xEC7cb8C3EBE77BA6d284F13296bb1372A8522c5F;
  address public TaxCollector_Address = 0x3C2BafebbB0c8c58f39A976e725cD20D611d01e9;
  address public StabilityFeeTreasury_Address = 0x5f246ADDCF057E0f778CD422e20e413be70f9a0c;
  address public GlobalSettlement_Address = 0x4c04377f90Eb1E42D845AB21De874803B8773669;
  address public PostSettlementSurplusAuctionHouse_Address = 0xf93b0549cD50c849D792f0eAE94A598fA77C7718;
  address public SettlementSurplusAuctioneer_Address = 0x8CeA85eC7f3D314c4d144e34F2206C8Ac0bbadA1;
  address public PIDController_Address = 0xCC5Bc84C3FDbcF262AaDD9F76652D6784293dD9e;
  address public PIDRateSetter_Address = 0x04F75a27cE2FDC591C71a88f1EcaC7e5Ce44f5Fc;
  address public AccountingJob_Address = 0x3Af511B1bdD6A0377e23796aD6B7391d8De68636;
  address public LiquidationJob_Address = 0x10537D7bD661C9c34F547b38EC662D6FD482Ae95;
  address public OracleJob_Address = 0xBD2fe040D03EB1d1E5A151fbcc19A03333223019;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x082e4B50a971f3f21d737069E6178EF8c84C68E3;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xCebaAa1B65A42E1732bC6424074aE86243B5E2E5;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xd19C3d1323A39f3929CA113A4C394212077daED4;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x90B903E140E90Ea572db3F1298e9C8cd6889EDd6;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xE9FcaA68546D5dFC774ac0880DA31EDA7D590bF5;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x2979117101eF615cfd83c07df58f06D9653fFca5;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x27c8542756292323E0a815d688e14361AE0C21A0;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x4DB00D4E9DE128A20D03697c27ae68C670FE30DD;
  address public Vault721_Address = 0x06786bCbc114bbfa670E30A1AC35dFd1310Be82f;
  address public ODSafeManager_Address = 0x82Bd83ec6D4bCC8EaB6F6cF7565efE1e41D92Ce5;
  address public NFTRenderer_Address = 0xD61210E756f7D71Cc4F74abF0747D65Ea9d7525b;
  address public BasicActions_Address = 0x7aB5cEee0Ff304b053CE1F67d84C33F0ff407a55;
  address public DebtBidActions_Address = 0x26Df0Ea798971A97Ae121514B32999DfDb220e1f;
  address public SurplusBidActions_Address = 0xA3b48c7b901fede641B596A4C10a4630052449A6;
  address public CollateralBidActions_Address = 0xa138575a030a2F4977D19Cc900781E7BE3fD2bc0;
  address public PostSettlementSurplusBidActions_Address = 0xB8d6D6b01bFe81784BE46e5771eF017Fa3c906d8;
  address public GlobalSettlementActions_Address = 0xf524930660f75CF602e909C15528d58459AB2A56;
  address public RewardedActions_Address = 0x6c383Ef7C9Bf496b5c847530eb9c49a3ED6E4C56;
}
