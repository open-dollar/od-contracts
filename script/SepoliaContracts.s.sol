// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract SepoliaContracts {
  address public SystemCoin_Address = 0x62CB71630E86c739206fa8c41E74Cf3292A56FBD;
  address public Vault721_Address = 0x05AC7e3ac152012B980407dEff2655c209667E4c;
  address public ProtocolToken_Address = 0xbbB4f37c787C6ecb0b6b5Fb3F73221aA22fabA70;
  address public TimelockController_Address = 0xC1b1A32Cb29E441A1a16cC1120aF47f2787D5000;
  address public ODGovernor_Address = 0x69ae232E574352232aB8678869eAA3BEBd885211;
  address public ChainlinkRelayerFactory_Address = 0x555691C860015a5CE8748296fbbAa624410F55A4;
  address public DenominatedOracleFactory_Address = 0xD18Ce4d87Bf1E8a959F9F9eC2dB5A8D639408580;
  address public DelayedOracleFactory_Address = 0x500E234652Ee1a8b06F99599Ae7d5299527270fB;
  address public MintableVoteERC20_ARB_Address = 0x3018EC2AD556f28d2c0665d10b55ebfa469fD749;
  address public MintableERC20_WSTETH_Address = 0x8c12A21C8D62d794f78E02aE9e377Abee4750E87;
  address public MintableERC20_CBETH_Address = 0x738f310D6a2E963BddCad7B94cF47F4238641f8e;
  address public MintableERC20_RETH_Address = 0x10f09B7d671378a5E85C64B49213F50513FA7343;
  address public ChainlinkRelayerChild_8_Address = 0x781Ce75aC5307E460280281113Fb842CE8f44dD8;
  address public DenominatedOracleChild_ARB_Address = 0x7f65502c518a75faDDF58981899F60023192aE1c;
  address public DenominatedOracleChild_RETH_Address = 0x0Ba27Dd96330A763Bd538e45Df58eD0F2CcF30f6;
  address public DelayedOracleChild_ARB_Address = 0x4A7e58f0Ee271189eb6eea37049f539890e5ec3f;
  address public DelayedOracleChild_WSTETH_Address = 0xD87806BE73a410A4c4CF6b1639d6E97b9403AB18;
  address public DelayedOracleChild_CBETH_Address = 0x62c1551060DEC04216d40cd1A2c70B27b18D3841;
  address public DelayedOracleChild_RETH_Address = 0x648E36ede1B8315c4f0e9d02FBE521B5be7c1dBd;
  address public SAFEEngine_Address = 0x2C3C51Eed16F6eAe6CF2607fFF5753dE6cc48Aa5;
  address public OracleRelayer_Address = 0xf52b9fC4e4A16cc1142d3aC7eA985Aa57DA4d9B3;
  address public SurplusAuctionHouse_Address = 0xB9fCb46313A76718b20b07C03b76cc606841ea9f;
  address public DebtAuctionHouse_Address = 0x72C97B46036Eea6c1Bf019a945E776e9e9021a09;
  address public AccountingEngine_Address = 0x3cEA7089C4A4a30084f735673F0b14F5699D70a5;
  address public LiquidationEngine_Address = 0xBac6C44596EB176205BCf5149ea87D430515B828;
  address public CollateralAuctionHouseFactory_Address = 0x5C95C7aebB8A84869EA0E8528C35BCb0725A3024;
  address public CoinJoin_Address = 0x5afdAd856c7CE87c1dE029aA8f68eeD1bC960e79;
  address public CollateralJoinFactory_Address = 0x174C33ED9CCA1F2a27Af7B6B6f2d3246a75eB8be;
  address public TaxCollector_Address = 0x69f01E76365B28eB3eb4B6e7134BF8dCb1057F21;
  address public StabilityFeeTreasury_Address = 0x40d322030606fEa2bEB177c6d72d85c96744CBc6;
  address public GlobalSettlement_Address = 0xdb27222024d1AfcB826397d2542812bA5D427f6D;
  address public PostSettlementSurplusAuctionHouse_Address = 0x265FDFE7e8673218B35DD35DEd44140931109572;
  address public SettlementSurplusAuctioneer_Address = 0x723eF642790d81cF74848550A610e4799CAa902f;
  address public PIDController_Address = 0xA1550dCfdb0195e0e1DECe7b6aad711da5eD303a;
  address public PIDRateSetter_Address = 0x9FdAc43F459d79A947C47E834e9b50633eB836Ab;
  address public AccountingJob_Address = 0x128F762a6Ed975D13E4862Aa43184A600f87f093;
  address public LiquidationJob_Address = 0x25Ab28fF1CDaC3e6d5Ab1BdE0474c36c2b85e4bf;
  address public OracleJob_Address = 0xA8335E371c392B3d4AEA3761AEEC3C6bED5Ce736;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x9BFdc8b1203D68555805Ee876b5Ac7C12194f07a;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xa9666259123536e9f48c3E3902Cc6BB60581F135;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x47AB26bd297ee35E7f24E25a23BD9115fd08dbFA;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xEFc43eB2ad013fcc45b6d838F58005BdB861B72b;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xfED5d80C383632eD86A728597818418C32B96760;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x754CaEa5a5863a9ee644Ee236662F0D7dD6F4Ed3;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xEAEd61cDA9a1F6eCF2d71b1554172DC64B757B30;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x8c8C4ECF299F3f737EECA58c4479469B83473244;
  address public ODSafeManager_Address = 0x518108913eE727745c3cF103fc451F9C39267FC0;
  address public NFTRenderer_Address = 0x8eCdCF2e917E5D380820b6f8D49782B51630fE8F;
  address public BasicActions_Address = 0xf22bB5BF9CD210Ff20dF43Bda1A26221DE872AC4;
  address public DebtBidActions_Address = 0x26fAfdDcCF893a3a24a9E06D7ba5E62d3bbAE1Be;
  address public SurplusBidActions_Address = 0x94B4046BE898a53A9ea97EbB83C3954BA0d70A3A;
  address public CollateralBidActions_Address = 0x75Eb82c9DF4EE6a99E7ca8967C0B1f7D6594c54E;
  address public PostSettlementSurplusBidActions_Address = 0xd7da4ED8f22A138417D16228FB432579AD00f2A0;
  address public GlobalSettlementActions_Address = 0x97a140f7b81B1cB87a47582562c43b54461a6484;
  address public RewardedActions_Address = 0x7b34c557C7b2f56471071AbED88893b1fB04A140;
}
