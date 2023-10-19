// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0xA67fC2847Afde3d99B79759c1433c657A3c315D5;
  address public UniV3RelayerFactory_Address = 0xE8A225302aE0f896730c8b2B1C48f62ab2B3Fab4;
  address public CamelotRelayerFactory_Address = 0xCC9823DE9a09F5e7bbC280D861D55bFba992c305;
  address public DenominatedOracleFactory_Address = 0x638203E81681881574B476F21ac7B9Adf2C0f4d1;
  address public DelayedOracleFactory_Address = 0x70C60b1cE0EA45957E7793ac110F5Ed52f6a65Da;
  address public MintableVoteERC20_Address = 0xDef3b542C46de7b9B62F9B772fAff1d3FD1Bd0Fe;
  address public MintableERC20_WSTETH_Address = 0x5E5676BFf56f932c2600100321916d19dBEF7B35;
  address public MintableERC20_CBETH_Address = 0x8e96CcfAE1f3D80f37D878012f8AFe4F40Fe0550;
  address public MintableERC20_RETH_Address = 0x8BAF64465a97d64854AF3A04aF7eb764429cB28f;
  address public MintableERC20_MAGIC_Address = 0xF7a422b89bDC7e01A1DFdE97163703BdF77C4392;
  address public ChainlinkRelayerChild_11_Address = 0x6009A84eD7Ac9333bc9fac8d1DA4e76b30D7c55B;
  address public DenominatedOracleChild_13_Address = 0x4f7cF7Fa07Fd3463B473b19D040C848fD77F0f4e;
  address public DenominatedOracleChild_15_Address = 0xceEd0789f0648d1236E73558d26D21C44Ed797f4;
  address public DenominatedOracleChild_17_Address = 0x2Ed0D5354D7CA76ed24fa2a7c9303abE3e99AF79;
  address public DelayedOracleChild_ARB_Address = 0xE725f3A8959d934EEC921CB9626E58d03b16C8Ba;
  address public DelayedOracleChild_WSTETH_Address = 0x0D7Feb568eB9F543E5f421232aD0a7F55Bab0748;
  address public DelayedOracleChild_CBETH_Address = 0x0C11A949Db29B964957795Ff6cE638B8731d7b93;
  address public DelayedOracleChild_RETH_Address = 0x6ea6Bb6dd117e1A1891B0AaEbA9a7EDC85b98CA0;
  address public DelayedOracleChild_MAGIC_Address = 0x1eD9B9C25176276e8A956902032dbFf2aB75A9e2;
  address public SystemCoin_Address = 0x42b98373e1BE732172683A97d2464708a876C3e7;
  address public ProtocolToken_Address = 0x2F0d90eE073B1211F6518601230b43029396b458;
  address public TimelockController_Address = 0xc5748e3fEc90F406C37fAE5c90bA2DB2582Fe181;
  address public ODGovernor_Address = 0x6787cD2e31F28fE5fa3eE769763ee2eC6c25aebD;
  address public SAFEEngine_Address = 0x4C885908F9d55291eb44B202f31FC05a701Cbe06;
  address public OracleRelayer_Address = 0x36c4E875F414961f7bFa68A6E64481B22a36aE18;
  address public SurplusAuctionHouse_Address = 0x3895F892f80E74A8D272702F8CcE887933cc813F;
  address public DebtAuctionHouse_Address = 0xcd0cb94F7dA0b1e0Cbfbdd24F805172ADe5D1c00;
  address public AccountingEngine_Address = 0x67315725a0c9Be8B531016A178eA8b562cE3cd28;
  address public LiquidationEngine_Address = 0x15983D95bdA6E311E75FC660e4d7Ef35646AD997;
  address public CollateralAuctionHouseFactory_Address = 0xfb8354f1faFc131c00f8c06323228061ebf607d6;
  address public CoinJoin_Address = 0xf4196e47Eb593b3124a143eBf0e92C919EB30f01;
  address public CollateralJoinFactory_Address = 0x58A1af31D1463Dd57aA70c2262F1F7FC4E477086;
  address public TaxCollector_Address = 0x5F019721eCc7C8a83a9e580695B0Dc1cCFEdedE8;
  address public StabilityFeeTreasury_Address = 0xE5150280dd070150cc5a67CC70CeaA169AD7dF86;
  address public GlobalSettlement_Address = 0x815350686993a3452d47514f2fCf2aa1Eb0761Be;
  address public PostSettlementSurplusAuctionHouse_Address = 0xa1BE637ce8D9d7509C350262cC4f5132906FaCbc;
  address public SettlementSurplusAuctioneer_Address = 0xb9f26F7F9daFcF4d933A4AEa293426FbF5652920;
  address public PIDController_Address = 0x420D57dDBD9d693DED7eBD0BE76cF35e13087995;
  address public PIDRateSetter_Address = 0xbB678B371D222983d6ED7e66d16bf91920bF5b8e;
  address public AccountingJob_Address = 0xeBdD8E47f74b7Cae290363103cfbdA740d39d311;
  address public LiquidationJob_Address = 0x2F12216d2e100EC2b0Ea7b8AA7a5B6A44f7270Ce;
  address public OracleJob_Address = 0x469c18C8962471BB09F2A47C1D8F16a65c5f7d61;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x957f66D6C13614a601806d599f48840226fb2F7c;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x99338e7b28586928602de14A0035cBC5283D6Dcd;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x5de75848760F30038239DD571C1D40D66DDC042F;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x1E9E52cB695558a184E5aC65a98152c0552B5cdE;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x370Cf45343ebd6de0E46d9913E088f238c1f806E;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xb025530CC0520A43De04A5DF7BBCf17ec0DE9b88;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x4499E75671A26480f9eACBf1305F6d13a33B53cD;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x5F160e1ccfCF631Aace205c648483490328EA963;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0x510b609D64A6Ddb3301c5c7BC4C3Ad15b8b1b89D;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0xd7F0A4E02ab820992a1d828B0d853e3B1F108896;
  address public Vault721_Address = 0xF5825966c34D18F4fE477FB7D6c6917BEedea8e9;
  address public ODSafeManager_Address = 0x29c1bce137678D10717f5932f876E33040fD9348;
  address public NFTRenderer_Address = 0x3bD72e04825A51f99CEeE4dB117FF0D56D3870d9;
  address public BasicActions_Address = 0xFeA58b8250A51AC8CF70e0Ae019B5F23b9480e68;
  address public DebtBidActions_Address = 0x96AB5C37714C5Ef126bfddb372E80a9B27eec1B1;
  address public SurplusBidActions_Address = 0x4Fa605309c9F0D3A39EA5Aa7d978a16bCeeC8b86;
  address public CollateralBidActions_Address = 0xd83F312d2A7E7DBbaDeB250C69d575a40c4Ace81;
  address public PostSettlementSurplusBidActions_Address = 0x956075a876C579abdC75E8ce35cd6E3a2953b50A;
  address public GlobalSettlementActions_Address = 0x5effac70F6085A5d40e0426a1e13B02F7A707838;
  address public RewardedActions_Address = 0x92Bfb4D96f0b8dcA8F6e5E0fc4713DEa8243d9D6;
}
