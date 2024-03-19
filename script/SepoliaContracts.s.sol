// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract SepoliaContracts {
  address public SystemCoin_Address = 0x0006d00Ae8375BDb0b10fBb100490CD5504fD802;
  address public ProtocolToken_Address = 0x000e59706a2d1151721F5ef09ad311985d4267f9;
  address public ChainlinkRelayerFactory_Address = 0x4aEC83896c73238d9Cbc4A31c9155123Ca18217D;
  address public DenominatedOracleFactory_Address = 0x6C64026E3262550754da734Cf62251fcdE3d38c1;
  address public DelayedOracleFactory_Address = 0x41350d74d0c1809f36e0a7ef72c25a7DdB8Cc2Ba;
  address public MintableVoteERC20_Address = 0x53865560cfA2d952F255Dd7d5c61C49C350a25Fd;
  address public MintableERC20_WSTETH_Address = 0x28708a74510BB214B685FfB371d593c51F597fC3;
  address public MintableERC20_CBETH_Address = 0xD2079b64b5858A4981675916a0d96B1e4A1495Ea;
  address public MintableERC20_RETH_Address = 0x9b1f544DCE4692A0B157bE6B9F20f1909899fFDB;
  address public ChainlinkRelayerChild_8_Address = 0x065Be96A46AE20946C405F02B6640b4def032b81;
  address public DenominatedOracleChild_10_Address = 0xCB59bC24949AFf7F2CDcDf14b3c3ecb3De01bF5e;
  address public DenominatedOracleChild_12_Address = 0x1f4E4480c9D80474FB181111F32ba778152A20Ab;
  address public DelayedOracleChild_ARB_Address = 0x1a0Ecc72daC5D15B1Ba001D3bE76f083aF2EFfA7;
  address public DelayedOracleChild_WSTETH_Address = 0xf9CbA6CD1b846fec6a971a2E017D8EfD8bF975A1;
  address public DelayedOracleChild_CBETH_Address = 0x2C13451a49c0F8506bEe5f421182683604efb55c;
  address public DelayedOracleChild_RETH_Address = 0xb564af73D71b7a0C7422b0D42F3d789b433e377B;
  address public TimelockController_Address = 0xB052d23F4Ffb146e48318b97fe9903b9e6D0ddC3;
  address public ODGovernor_Address = 0xA5DC5C86212cF22167c52b756363B0FeA7B6e591;
  address public SAFEEngine_Address = 0x1f5a89FD455FD216B34C406a643B963fe5ceA590;
  address public OracleRelayer_Address = 0xf4dcD9000922b42854E7fE54F3E2a2DC22Cc6Ed5;
  address public SurplusAuctionHouse_Address = 0x59F7e0B28A9a5F1c19c186Db696d4D7ADCac806F;
  address public DebtAuctionHouse_Address = 0x0905014Fe6C74e691c2cd00e0f1F8c4561D629C8;
  address public AccountingEngine_Address = 0xCcb14A69Eae9eA51F16D7C602c621303Af1Fbc22;
  address public LiquidationEngine_Address = 0x76d90151Ae5bD1Fc5e09F5A02A42824E26a323DB;
  address public CollateralAuctionHouseFactory_Address = 0x45C9D97AcA464162C4499527AD20683dE47a3dE9;
  address public CoinJoin_Address = 0xc72E00bbce6E76bb48e44B0F1BC92D5f15a5af73;
  address public CollateralJoinFactory_Address = 0x0B1F7a0d2F71452a21E2805042E56Ae28ce755aC;
  address public TaxCollector_Address = 0x6CB85048caaA1d670Ad4AFa18d3c3de1C45b0C74;
  address public StabilityFeeTreasury_Address = 0xa385Eb5603FD0d8223a66520EEfA366cD987ff40;
  address public GlobalSettlement_Address = 0x8B777768Eba27f1161b1573d8A5e7334f4714a5A;
  address public PostSettlementSurplusAuctionHouse_Address = 0x2e83b2836766479d1E0Fe56B42A5988e85E0C4d7;
  address public SettlementSurplusAuctioneer_Address = 0x4120291384d23dC591Df57a591AB7055923BfAf0;
  address public PIDController_Address = 0x2241ed6EA90FFd6fad2e586FF630A52c4020E340;
  address public PIDRateSetter_Address = 0xAa39DD9cFfB9984A8ab5Ae3daeE1770Ef07Afd98;
  address public AccountingJob_Address = 0xfbC2F8ff792B924644CFE88cf75E6373c93c0186;
  address public LiquidationJob_Address = 0x8E1Ce955669121ac719107660EA17505AD1Dba34;
  address public OracleJob_Address = 0xF1c6949E650b3b644e9B297A7f8472A23f52803B;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0xAf8F2CE440509279645e8747c0DBc2700ce0559F;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x1C788DD757060ee01aF63C772aA2eB58b60152aE;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x64d50121A7CC5E5FC7D7A3b8a989882b3a130a14;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xfF5C82f097ec061AEb381987E55c0789e079EaD5;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x1163D5a95AdBCe8b790A6e2a3de1737bE3C101CC;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x802e5bdd6A55F9aF350d3CbF5468Ee5232fD4736;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x8fF16f9f510f699fe1D9ae9778185557c59378e8;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x5ff631684f3dcF6430764C002b7184b9757C814c;
  address public Vault721_Address = 0x00024F3c588d9a1c11Be800637b43E0C88befF1A;
  address public ODSafeManager_Address = 0xea1bF408bF3f29C4787712E67390552163a465f3;
  address public NFTRenderer_Address = 0xAbAfb6e349354A1897E385A46DF01eC6c945730D;
  address public BasicActions_Address = 0x4e8a80c3A8bDD1BD1e7a85ad31b7adfC347cBF12;
  address public DebtBidActions_Address = 0x51905778Af208271a6Cb817617C21ACa961C3B20;
  address public SurplusBidActions_Address = 0x3DE22DE876C56011c3Ffa6139f089138e34bB538;
  address public CollateralBidActions_Address = 0x696C34Dfcc907e93cbAb4924126664E79b0b155c;
  address public PostSettlementSurplusBidActions_Address = 0x8c6A844c3adCe310B7502C137eb1Ad4B9B0dDced;
  address public GlobalSettlementActions_Address = 0x555b26c14eB5Fbc6483E1A749DAF470520de1991;
  address public RewardedActions_Address = 0xc9c31849a7f32885A0f1BDE98ec9181F06198CfD;
}
