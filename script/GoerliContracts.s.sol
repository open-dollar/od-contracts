// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x73CF85bb483b2eC3eF90Ae1EEb26715Eeca22eba;
  address public UniV3RelayerFactory_Address = 0x40BB3B644Ec160Dc570818d0DaC82c7c32f190b3;
  address public CamelotRelayerFactory_Address = 0x2F9104C8B6766074a5fF088dB44f16B035D63349;
  address public DenominatedOracleFactory_Address = 0x1e2a2c5A903724d14CfcbF4B829394Bb90BB9B19;
  address public DelayedOracleFactory_Address = 0xc199D5322a58c7E35237A4e2E3100A046eEe90f0;
  address public ChainlinkRelayerChild_6_Address = 0xbD6348deCF3313a8265E2990Dd7939E18535E6fD;
  address public DenominatedOracleChild_8_Address = 0xcf70A50af55AAeEAEf38dB7137Bb6Fb6868af612;
  address public MintableERC20_WSTETH_Address = 0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f;
  address public MintableVoteERC20_ARB_Address = 0x0Ed89D4655b2fE9f99EaDC3116b223527165452D;
  address public MintableERC20_CBETH_Address = 0x422d6eB01C86DAEcaa9BEd0b57Dc04294EeB2991;
  address public MintableERC20_RETH_Address = 0xeAe382e8cC9B6687683d4Ad59de30730a9D53803;
  address public MintableERC20_MAGIC_Address = 0x9485de7A78097398Aec74C930c82A67eee5c496b;
  address public ChainlinkRelayerChild_12_Address = 0x097A06dca8E17cC1C0a7D9B6F7846F27662f284d;
  address public DenominatedOracleChild_14_Address = 0x5d68E0A096981986a3BF80Ba8daa6199dD469a15;
  address public DenominatedOracleChild_16_Address = 0xBa9CD4905ade9B76b21005c9F3a81F3439F942Ed;
  address public DelayedOracleChild_WETH_Address = 0xCE64475dF2CDbB10Cf9BC72Feb324967C028BC64;
  address public DelayedOracleChild_ARB_Address = 0x713B0abac0A0948A35797a5Aa9a7837F06701027;
  address public DelayedOracleChild_WBTC_Address = 0x7563842bcB0b748e168A32b515c3CD7C7D7FEbD3;
  address public DelayedOracleChild_STONES_Address = 0x412b40c0208C5AA3DDfAD4D0E7333Cf44E4E5B36;
  address public DelayedOracleChild_TOTEM_Address = 0x2C905CD95818e7573d335Dc539734995B17cEAa0;
  address public SystemCoin_Address = 0x9a8c7c709839EbA4B0C5DbfAD38Ed9b712A31a3C;
  address public ProtocolToken_Address = 0x84D59476D70b6C0F00D60d9E6eD811d9E83118d5;
  address public SAFEEngine_Address = 0x70E2ac0Aa8AfF6316808A47436Bb09f674f87827;
  address public OracleRelayer_Address = 0xbF0b62F8C50090F729B176e8c4106D49B9c8EAE9;
  address public SurplusAuctionHouse_Address = 0x701572AA1Db1965300ADad95e21687834611a8a9;
  address public DebtAuctionHouse_Address = 0xC6B113e4c6F13162A8f8149D764E25272B1D0771;
  address public AccountingEngine_Address = 0x150D3f92DED9713592593EC74af834c4eaB1C5e0;
  address public LiquidationEngine_Address = 0x3412b012C056aFd89453e200d2C62321f4c68939;
  address public CollateralAuctionHouseFactory_Address = 0xc8062817d63a4eC3AD465afa37894b4058E7230C;
  address public CoinJoin_Address = 0x8A65b144d940cCFdc292A43E046754a3Fd87538b;
  address public CollateralJoinFactory_Address = 0x51685612573F67853B67162d3B15e8872fdAD606;
  address public TaxCollector_Address = 0xa4c7eA8eB64a0d1c5666afC0166Bd0dfbe0FB9C2;
  address public StabilityFeeTreasury_Address = 0xEE198092c4F39Fe2D8adA345715f3D3C15aBF360;
  address public GlobalSettlement_Address = 0x3a90F0030b8599E88fB4f3A4303b2152bC3c276A;
  address public PostSettlementSurplusAuctionHouse_Address = 0x0Eab5893C868432a1c7769dad618B14C4a14A1bE;
  address public SettlementSurplusAuctioneer_Address = 0x70F16b0796E5b542b380B52f519eCAc351f08e2A;
  address public PIDController_Address = 0x768fD1EAC0A5aEFFE63385f5244952f1D6d4f237;
  address public PIDRateSetter_Address = 0xA4AE244204BD9D1b918B6d30B19097530D4516A0;
  address public AccountingJob_Address = 0x72ED2F5E9899F84223Fc7fc4F965d8B668B888d3;
  address public LiquidationJob_Address = 0x7c533401714bd86e4d06Ebf440313fd3593c038F;
  address public OracleJob_Address = 0xd591f9C718d3ac1d1F53664B04c248c97c5a1828;
  address public CollateralJoinChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address =
    0xF807f5b6E9f7891178FfC6005e70CDC4af1f44aE;
  address public
    CollateralAuctionHouseChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address =
      0x9E779a5F70DBf488cee0c0fe7737bf35Db1a07bA;
  address public CollateralJoinChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address =
    0xB3a8efDBA29fb701006060f02eb95f9D1630CFBC;
  address public
    CollateralAuctionHouseChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address =
      0xD62cA551a2020DfEa030eA3E811F641df86c5aBd;
  address public CollateralJoinChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address =
    0x8FB2B20430961bF94124FFa7A749c856B185b4DD;
  address public
    CollateralAuctionHouseChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address =
      0x6ea1C41521e5761e0Bb31D009c630470EcBe6b30;
  address public CollateralJoinChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address =
    0x6fdb9C0eD5EC5A94fbd78af9E93b2A3f7c5cF076;
  address public
    CollateralAuctionHouseChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address =
      0x230644DE87cbfF7244c444dce09E772bC4f470D2;
  address public CollateralJoinChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address =
    0x3f800B236dac660B1B3206dAa40e3A86a1a579B6;
  address public
    CollateralAuctionHouseChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address =
      0x64B43945fD7D6486d3eB978BF5cf3f205B98D23D;
  address public TimelockController_Address = 0x53a5ae24939CB6A6776296E89fF107b618eDCe4A;
  address public ODGovernor_Address = 0x100E654e20CD3e415D018eF423a0BacE93C83f30;
  address public Vault721_Address = 0xD8970af0878fB9437c4b1c788C333e5F0E40eFB3;
  address public ODSafeManager_Address = 0xf4ac690C6457AD6629206Ad4CCB45545860F3AcA;
  address public NFTRenderer_Address = 0x8338C738665F3C42c41Af19334306b3dfd708A2a;
  address public BasicActions_Address = 0xE81956bd8Fec817A442FD2f3531A2f81C3090ceF;
  address public DebtBidActions_Address = 0xC7F4cfce44EC28001517eee4625541F833f8F747;
  address public SurplusBidActions_Address = 0xFa90fD507e129B9b168306522C6e2e95bB349F39;
  address public CollateralBidActions_Address = 0xb6f8AF22cd29759ae70d6d3A44E3161BdCeBd825;
  address public PostSettlementSurplusBidActions_Address = 0x1876e48C23f2B5a735465CC8b723DB23fD67E0dD;
  address public GlobalSettlementActions_Address = 0xd77b283F2fe0b04e5eF12da4a9d50f0784A08dDF;
  address public RewardedActions_Address = 0x09d73dCE94069372D7cd921a7027CF6cf788Cb34;
  address public AlgebraChild_Address = 0x186718CC934e87DEBCD507F8E652E08a83996DeF;
  address public CamelotRelayerChild_126_Address = 0xBC4c155270d3C607574ECad3BE80DD00c5f0f5c1;
  address public DenominatedOracleChild_OD_Address = 0xa1D509D691636E2fDc6bFb038f4e4E59db2380Fe;
}
