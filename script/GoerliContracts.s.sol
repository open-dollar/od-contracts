// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
    address public ChainlinkRelayerFactory = 0x30951E52b32E380C690D84613E4603F866d2E104
    address public UniV3RelayerFactory = 0x7390f597F63604Df8d0Ca43BAFc2bA994A0db3E9
    address public CamelotRelayerFactory = 0x6D38DCE63fE77A0c5501f9D68e53E8BB783b1EFc
    address public DenominatedOracleFactory = 0x533ED646218E330e29D473D8230A50f4e7B1b0db
    address public DelayedOracleFactory = 0xB72A2799Ee246FD2445a6F33B577e21C6579E988
    address public MintableERC20 = 0x7D26c8d67e683a2b57fE53B028dbA577dc134944
    address public SystemCoin = 0xD578921C95240A01FEB96Fb6c92c06bb86d1aA64
    address public ProtocolToken = 0xeCE206326B3429B7f7359d417d1B7c638341A28A
    address public SAFEEngine = 0x7A53a75462e8818eC594c0bc8cA93dEA4960073e
    address public OracleRelayer = 0x50D957722b912a1310Ec0434173598ec677dA854
    address public SurplusAuctionHouse = 0x6EBaC41c6E91a2502B45ECB778a26767B12C3D00
    address public DebtAuctionHouse = 0xCAb8F00dc5e23B4c913a72fB3a8550A92895511E
    address public AccountingEngine = 0x59cdb635DB3CC082201D8A810326D87312DdEDb8
    address public LiquidationEngine = 0xB977e30EC25Abf4023Cd49925e86719C00507bF4
    address public CollateralAuctionHouseFactory = 0x200a000EC2F57a3190a67BB38131e154dD8E01B8
    address public CoinJoin = 0xBC46ec43A84382Bbf4996E7206619Ba87bc96506
    address public CollateralJoinFactory = 0x4C194DDcA4a2049B1F5F791D6FFaBc99d96a1f17
    address public TaxCollector = 0x58571a80316e723A2d8D19E0Ad64F94205a9a61b
    address public StabilityFeeTreasury = 0xB7Bf91DB447D23858d0d7eb8B84E73a2D43462A5
    address public GlobalSettlement = 0xcDF9A3a54ab9226d3B526834f55BBced173fDfc9
    address public PostSettlementSurplusAuctionHouse = 0xEDC5dAb89f5fA3b494214e8e45049909CaF22D44
    address public SettlementSurplusAuctioneer = 0x484e5de96258e25704573654dbeF13Ff0747a578
    address public PIDController = 0x0E46dD550e135144F48D2deBFd3DaFdeeaB3D8cc
    address public PIDRateSetter = 0xA86C4EfF26cFbEFaeDd30B05eddE37B838796761
    address public AccountingJob = 0x62e9b480820c0472591fab8b141600504997C2ac
    address public LiquidationJob = 0x4857717aDF0A535fc117F2018128d2321a3dB0d7
    address public OracleJob = 0xa2d98F347e19a45baBb23c4a5243a365dc7fb16A
    address public Vault721 = 0xdbB05E2334EF998A841574C460C410fB357d9cC1
    address public ODSafeManager = 0x6D466C9A07D397756921e06E1840Ba91cC63750e
    address public NFTRenderer = 0x216F9d116E5490c01a990562f1aCa09e6E763cb3
    address public BasicActions = 0x5CC553A0BC7BF76b5C424420CC8c5649b893656A
    address public DebtBidActions = 0x12B35b6c3F5b5355717D2D0e18Bfab9bC0f1117b
    address public SurplusBidActions = 0x9bb386eb654AB80eC8CB173d517659d5B0987183
    address public CollateralBidActions = 0x6b2A3B669e1f5EfA147d2802a8d3abB662d3F305
    address public PostSettlementSurplusBidActions = 0x6075F94908b2dd0076b7de6d4B1Ac06E57282E3E
    address public GlobalSettlementActions = 0x1314fbe354Db75120CFFE6483Dd73CE50A0870F6
    address public RewardedActions = 0x247B391046bF6bA62587EB0a748cf182Fe2f03DE
    address public TimelockController = 0x43E888fB33481b3bC0dC917c47db3b456647A8eA
    address public ODGovernor = 0x191600244f20E5139dE157e3F7dc6740e48b52F4

}