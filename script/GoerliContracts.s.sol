// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x3609eDA8370be89B61c961712ef923Bb672255a3;
  address public UniV3RelayerFactory_Address = 0x26e18a8ceE2e35764d7123850C253165C1775aF0;
  address public CamelotRelayerFactory_Address = 0x185A05131D151139776d9C1631c4AafbD29301c6;
  address public DenominatedOracleFactory_Address = 0xF9Ac797ED5509790ead9407C73723214a4dBcECD;
  address public DelayedOracleFactory_Address = 0xAAB0138Be8d1100d3Bf7060015979FE127c6b388;
  address public ChainlinkRelayerChild_6_Address = 0xa6F2CcE47e4d3919E37729234b45252F2196C9d2;
  address public DenominatedOracleChild_8_Address = 0x3841B06cc0A4e9fA4Bb61F7BB54cc7b6c450B107;
  address public MintableERC20_WBTC_Address = 0x43bbfd2e3FdF85b14E053B39Dc8e0e49cF3e3deF;
  address public MintableERC20_STONES_Address = 0xfCe71735bC50b6c0378FFBF57b585dd7CDbD7Ae9;
  address public MintableERC20_TOTEM_Address = 0xba3C44f68bc32733734b8293A6478451D2602691;
  address public ChainlinkRelayerChild_12_Address = 0x9B6677cC286763513A4152191De00258d465F40b;
  address public DenominatedOracleChild_14_Address = 0x4e5B16F1219b0ABD4240538cC9a9EAA24830B311;
  address public DenominatedOracleChild_16_Address = 0xd97516F7eE936561b7240ec1f4190E3b01cC2D61;
  address public DelayedOracleChild_WETH_Address = 0x6Ad8e880F8f302AEbE0478B7F3C6C4460ba81aA5;
  address public DelayedOracleChild_FTRG_Address = 0x13a346D11576733F73eff06f8A288D62994Af4b5;
  address public DelayedOracleChild_WBTC_Address = 0xE6CecDc9570b280f2be88c977cCfaa014f1c7B06;
  address public DelayedOracleChild_STONES_Address = 0x41581c4d601181C1354AA0Aa69cf7BA1Fb7b35F1;
  address public DelayedOracleChild_TOTEM_Address = 0x0Fdb07f60F35Ad6ed0FB2AaA82b360Ccb04D2C47;
  address public SystemCoin_Address = 0xF067Afbd6e6060221eACf9604Fb3793B4177e803;
  address public ProtocolToken_Address = 0x971b031E68198f601bA630c76F9d23570176A05C;
  address public SAFEEngine_Address = 0x8f1AC27A4BFBbCE175069f18FDBf86A4793Ca197;
  address public OracleRelayer_Address = 0x201df35f138f0055DC8bd16834917F0f2821bDF1;
  address public SurplusAuctionHouse_Address = 0x154E0f232e4025d61334f0fe98018ef580752d33;
  address public DebtAuctionHouse_Address = 0xd70c85230042DCa61B047b55E34Dc57Ef3043844;
  address public AccountingEngine_Address = 0x739323c1C78BF69b98eb5c54e26CBc84D9e7Aeb5;
  address public LiquidationEngine_Address = 0x3Ed9a06B8f26C2576f6B433c8d15a772dE6Eda0b;
  address public CollateralAuctionHouseFactory_Address = 0x9525890aCdB0628D67756346C26b0B740c27163c;
  address public CoinJoin_Address = 0x44435aF63202ec9b5Fa24f13DFa3f225b927FaE6;
  address public CollateralJoinFactory_Address = 0x61eDAb0F644450A9b9C85104fc82a4dbc537aDB7;
  address public TaxCollector_Address = 0xd4177ffe4f1A3b92d1A3f105e438e73fB74b17f6;
  address public StabilityFeeTreasury_Address = 0xa1aBe1B5761D2D868e8AeE00006ba98c485403ae;
  address public GlobalSettlement_Address = 0x321a3cC11b1b69edB6DBd4de7B8bbe28991000CB;
  address public PostSettlementSurplusAuctionHouse_Address = 0x9E819798088F586d5DCcEDFdcEF917336Ce986Ec;
  address public SettlementSurplusAuctioneer_Address = 0x4Add62ECe30b850AF121cE59e5aD8A15aFA184bd;
  address public PIDController_Address = 0xd486E7ecBA777DBe9d2dd4452404DF82961E9542;
  address public PIDRateSetter_Address = 0x0A4aA226278FA7aA583C8Ef9d07aAb3D2412273c;
  address public AccountingJob_Address = 0x98Fc5bF4226EDDF96f51657bFb6A64fdde65191e;
  address public LiquidationJob_Address = 0x04452707eD6Fd9A322648611F6980aA4Ed06AB1A;
  address public OracleJob_Address = 0xdD149aD9F1e8B6776Fb0B788bF4e9EB16F6f2b0D;
  address public CollateralJoinChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address =
    0x4f9D68D4c0C0b35699fc1D5892c0622c4d670306;
  address public
    CollateralAuctionHouseChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address =
      0x9A9622DbD4746e783e2C1d3ed9efc822DEa9E632;
  address public CollateralJoinChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address =
    0xA8072C6B748abb495121ADe3e8Da6f06A94f9E48;
  address public
    CollateralAuctionHouseChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address =
      0xcbD6d645767eD69d91B8ca3Efa82FA11Cd66F055;
  address public CollateralJoinChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address =
    0x9C626fcE9915D8ef370F1132D628896d9F2cd878;
  address public
    CollateralAuctionHouseChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address =
      0x177758b6407F4A43D253025deA9B8c74cDA0EDBa;
  address public CollateralJoinChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address =
    0xC2aACDd7b1240e1555077f14c2150a3A69Ba2b0b;
  address public
    CollateralAuctionHouseChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address =
      0xfB936243850A0f43a324DE9FE46B3079FcC32640;
  address public CollateralJoinChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address =
    0xf3908F0a28640797a229750D78d7F1793e33938A;
  address public
    CollateralAuctionHouseChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address =
      0xa0702282666f361644fB74D9c1546Acbf27c35B3;
  address public Vault721_Address = 0xB2BB0b60E01Ed0d80B7764f86d3c2b30818C37cd;
  address public ODSafeManager_Address = 0x9Ca0Fbe890aBcC5e17CC88B4d21B82dCF095d99A;
  address public NFTRenderer_Address = 0x4DAB63971143236352DE6C8076B2B60C55A430dd;
  address public BasicActions_Address = 0x92Df6791659aF5D45d8e6Ef2BFA4A428F476F105;
  address public DebtBidActions_Address = 0x45Fca9B81e5d72047fF5f11d5c25928A6518b4c4;
  address public SurplusBidActions_Address = 0x3C175007711169135B57E6C49aE841eF2d9955Bd;
  address public CollateralBidActions_Address = 0x4957636209cFbcC2e06ad8b8D2DFFa51cc82c41f;
  address public PostSettlementSurplusBidActions_Address = 0x58eC39B32dea54DCD68910501659487B0C2a5A6C;
  address public GlobalSettlementActions_Address = 0x45364533535E2eeE89513d41060076618eAd256D;
  address public RewardedActions_Address = 0x5a12E08FBd502aF65F4fc0f694dFdEa9947e9DA7;
  address public TimelockController_Address = 0xE9dD547a8297D07dAf803C46a5cC187bF274Cf81;
  address public ODGovernor_Address = 0xa45499121D029805b79B48761958Bc705053e474;
  address public DenominatedOracleChild_OD_Address = 0x8ED0E6d53cf08EE85EC5acc61AECB4A6e1da7421;

  // post deployment
  address public CamelotPool_Address = 0xc16763b670d5B8360fE1c7AB03C43BCE418431a5; // OD / WETH
  address public CamelotRelayerChild_Address = 0x97eDe6FFaaA866a749bc230B2aDF7B86Ba7a9946; // OD / WETH
  address public CamelotDenominatedOracleChild_Address = 0xCB0361b563efD1E7cC42308034b3D8BDAc24b7e8; // (OD / WETH) * (ETH / USD)
}
