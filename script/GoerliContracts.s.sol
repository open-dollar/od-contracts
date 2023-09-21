// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x30951E52b32E380C690D84613E4603F866d2E104;
  address public UniV3RelayerFactory_Address = 0x7390f597F63604Df8d0Ca43BAFc2bA994A0db3E9;
  address public CamelotRelayerFactory_Address = 0x6D38DCE63fE77A0c5501f9D68e53E8BB783b1EFc;
  address public DenominatedOracleFactory_Address = 0x533ED646218E330e29D473D8230A50f4e7B1b0db;
  address public DelayedOracleFactory_Address = 0xB72A2799Ee246FD2445a6F33B577e21C6579E988;
  address public ChainlinkRelayerChild_6_Address = 0xFc7F98CFa1e1deb7b2d222E69780736960A7e6AC;
  address public DenominatedOracleChild_8_Address = 0xAc96D9f510A3C2Ec8BA5C4533ea4D59aE7ACeA43;
  address public MintableERC20_WBTC_Address = 0xd1ef71e2De83d70dB58d56beD5b237f69Da948DA;
  address public MintableERC20_STONES_Address = 0x8D0c3C5A2EB5f1171AA52cAF932832309Ff933Aa;
  address public MintableERC20_TOTEM_Address = 0x7D26c8d67e683a2b57fE53B028dbA577dc134944;
  address public ChainlinkRelayerChild_12_Address = 0x5A6FC187129e1dd97BafFd17c0FB24f725C8870c;
  address public DenominatedOracleChild_14_Address = 0x666BA8A7882a20FB5d5A3591b5da29af907f94e7;
  address public DenominatedOracleChild_16_Address = 0xE6e62A95c77C1D4034A39c09AA92e255B11eC869;
  address public DelayedOracleChild_WETH_Address = 0xA977adA123bae3C65eb828E15196CE3DEA763a0E;
  address public DelayedOracleChild_FTRG_Address = 0x36E91d510D492b87813Bb49704423b3b5885201F;
  address public DelayedOracleChild_WBTC_Address = 0xB8AEea1DDCdC4E7763c4f470719Dc24D6D4D2D49;
  address public DelayedOracleChild_STONES_Address = 0xCd7854ac8f8e97a8413B4499f428974255493F10;
  address public DelayedOracleChild_TOTEM_Address = 0x720072D1D582f078117C954f58eB8Af46230d955;
  address public SystemCoin_Address = 0xD578921C95240A01FEB96Fb6c92c06bb86d1aA64;
  address public ProtocolToken_Address = 0xeCE206326B3429B7f7359d417d1B7c638341A28A;
  address public SAFEEngine_Address = 0x7A53a75462e8818eC594c0bc8cA93dEA4960073e;
  address public OracleRelayer_Address = 0x50D957722b912a1310Ec0434173598ec677dA854;
  address public SurplusAuctionHouse_Address = 0x6EBaC41c6E91a2502B45ECB778a26767B12C3D00;
  address public DebtAuctionHouse_Address = 0xCAb8F00dc5e23B4c913a72fB3a8550A92895511E;
  address public AccountingEngine_Address = 0x59cdb635DB3CC082201D8A810326D87312DdEDb8;
  address public LiquidationEngine_Address = 0xB977e30EC25Abf4023Cd49925e86719C00507bF4;
  address public CollateralAuctionHouseFactory_Address = 0x200a000EC2F57a3190a67BB38131e154dD8E01B8;
  address public CoinJoin_Address = 0xBC46ec43A84382Bbf4996E7206619Ba87bc96506;
  address public CollateralJoinFactory_Address = 0x4C194DDcA4a2049B1F5F791D6FFaBc99d96a1f17;
  address public TaxCollector_Address = 0x58571a80316e723A2d8D19E0Ad64F94205a9a61b;
  address public StabilityFeeTreasury_Address = 0xB7Bf91DB447D23858d0d7eb8B84E73a2D43462A5;
  address public GlobalSettlement_Address = 0xcDF9A3a54ab9226d3B526834f55BBced173fDfc9;
  address public PostSettlementSurplusAuctionHouse_Address = 0xEDC5dAb89f5fA3b494214e8e45049909CaF22D44;
  address public SettlementSurplusAuctioneer_Address = 0x484e5de96258e25704573654dbeF13Ff0747a578;
  address public PIDController_Address = 0x0E46dD550e135144F48D2deBFd3DaFdeeaB3D8cc;
  address public PIDRateSetter_Address = 0xA86C4EfF26cFbEFaeDd30B05eddE37B838796761;
  address public AccountingJob_Address = 0x62e9b480820c0472591fab8b141600504997C2ac;
  address public LiquidationJob_Address = 0x4857717aDF0A535fc117F2018128d2321a3dB0d7;
  address public OracleJob_Address = 0xa2d98F347e19a45baBb23c4a5243a365dc7fb16A;
  address public CollateralJoinChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address =
    0x1AA05FbC6300fDA64159B6098aC78dE784f7Da01;
  address public
    CollateralAuctionHouseChild_0x5745544800000000000000000000000000000000000000000000000000000000_Address =
      0x66b698fAcD75c6ED5fbc0cA87a62DFf11A6355DA;
  address public CollateralJoinChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address =
    0x49eDffDa17a4b31294f4223E20E0C05bFAd7b546;
  address public
    CollateralAuctionHouseChild_0x4654524700000000000000000000000000000000000000000000000000000000_Address =
      0xD81A45066d293F4e030C3f6fD9D96ae1D0316163;
  address public CollateralJoinChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address =
    0xcD433486B57484d01DD00430528D989d1AA61FB8;
  address public
    CollateralAuctionHouseChild_0x5742544300000000000000000000000000000000000000000000000000000000_Address =
      0x68230FC156398C7113bB409c4891ff51026A23E2;
  address public CollateralJoinChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address =
    0xd1aB4CEA5C6518c95A778702b1240c3dEaEeb17b;
  address public
    CollateralAuctionHouseChild_0x53544f4e45530000000000000000000000000000000000000000000000000000_Address =
      0x6Ce47cb2F82cDd59C2FCB3b04e7eBa0ee0299e4D;
  address public CollateralJoinChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address =
    0x3801c46554FEbA1dfe627A467333fbAD93D88d6A;
  address public
    CollateralAuctionHouseChild_0x544f54454d000000000000000000000000000000000000000000000000000000_Address =
      0x628147b13DDc5Ad4d47BCCb75e343237ad10996B;
  address public Vault721_Address = 0xdbB05E2334EF998A841574C460C410fB357d9cC1;
  address public ODSafeManager_Address = 0x6D466C9A07D397756921e06E1840Ba91cC63750e;
  address public NFTRenderer_Address = 0x216F9d116E5490c01a990562f1aCa09e6E763cb3;
  address public BasicActions_Address = 0x5CC553A0BC7BF76b5C424420CC8c5649b893656A;
  address public DebtBidActions_Address = 0x12B35b6c3F5b5355717D2D0e18Bfab9bC0f1117b;
  address public SurplusBidActions_Address = 0x9bb386eb654AB80eC8CB173d517659d5B0987183;
  address public CollateralBidActions_Address = 0x6b2A3B669e1f5EfA147d2802a8d3abB662d3F305;
  address public PostSettlementSurplusBidActions_Address = 0x6075F94908b2dd0076b7de6d4B1Ac06E57282E3E;
  address public GlobalSettlementActions_Address = 0x1314fbe354Db75120CFFE6483Dd73CE50A0870F6;
  address public RewardedActions_Address = 0x247B391046bF6bA62587EB0a748cf182Fe2f03DE;
  address public TimelockController_Address = 0x43E888fB33481b3bC0dC917c47db3b456647A8eA;
  address public ODGovernor_Address = 0x191600244f20E5139dE157e3F7dc6740e48b52F4;
  address public DenominatedOracleChild_OD_Address = 0xBd66381A999711d1Dcdd7947877C127c6A1769a1;
}
