// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract AnvilContracts {
  // forgefmt: disable-start
    address public ChainlinkRelayerFactory_Address = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address public UniV3RelayerFactory_Address = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address public CamelotRelayerFactory_Address = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address public DenominatedOracleFactory_Address = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address public DelayedOracleFactory_Address = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
    address public MintableVoteERC20_Address = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    address public MintableERC20_7_Address = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
    address public MintableERC20_8_Address = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;
    address public MintableERC20_9_Address = 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318;
    address public MintableERC20_10_Address = 0x610178dA211FEF7D417bC0e6FeD39F05609AD788;
    address public DenominatedOracleChild_13_Address = 0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81;
    address public DenominatedOracleChild_15_Address = 0x6D544390Eb535d61e196c87d6B9c80dCD8628Acd;
    address public DenominatedOracleChild_17_Address = 0xB1eDe3F5AC8654124Cb5124aDf0Fd3885CbDD1F7;
    address public DenominatedOracleChild_19_Address = 0xA6D6d7c556ce6Ada136ba32Dbe530993f128CA44;
    address public DelayedOracleChild_20_Address = 0x856e4424f806D16E8CBC702B3c0F2ede5468eae5;
    address public DelayedOracleChild_21_Address = 0xb0279Db6a2F1E01fbC8483FCCef0Be2bC6299cC3;
    address public DelayedOracleChild_22_Address = 0x3dE2Da43d4c1B137E385F36b400507c1A24401f8;
    address public DelayedOracleChild_23_Address = 0xddEA3d67503164326F90F53CFD1705b90Ed1312D;
    address public DelayedOracleChild_24_Address = 0xAbB608121Fd652F112827724B28a61e09f2dcDf4;
    address public SystemCoin_Address = 0x4A679253410272dd5232B3Ff7cF5dbB88f295319;
    address public ProtocolToken_Address = 0x7a2088a1bFc9d81c55368AE168C2C02570cB814F;
    address public SAFEEngine_Address = 0x09635F643e140090A9A8Dcd712eD6285858ceBef;
    address public OracleRelayer_Address = 0xc5a5C42992dECbae36851359345FE25997F5C42d;
    address public SurplusAuctionHouse_Address = 0x67d269191c92Caf3cD7723F116c85e6E9bf55933;
    address public DebtAuctionHouse_Address = 0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E;
    address public AccountingEngine_Address = 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690;
    address public LiquidationEngine_Address = 0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB;
    address public CollateralAuctionHouseFactory_Address = 0x9E545E3C0baAB3E08CdfD552C960A1050f373042;
    address public CoinJoin_Address = 0xa82fF9aFd8f496c3d6ac40E2a0F282E47488CFc9;
    address public CollateralJoinFactory_Address = 0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8;
    address public TaxCollector_Address = 0x851356ae760d987E095750cCeb3bC6014560891C;
    address public StabilityFeeTreasury_Address = 0xf5059a5D33d5853360D16C683c16e67980206f36;
    address public GlobalSettlement_Address = 0x4c5859f0F772848b2D91F1D83E2Fe57935348029;
    address public PostSettlementSurplusAuctionHouse_Address = 0x1291Be112d480055DaFd8a610b7d1e203891C274;
    address public SettlementSurplusAuctioneer_Address = 0x5f3f1dBD7B74C6B46e8c44f98792A1dAf8d69154;
    address public PIDController_Address = 0xB0D4afd8879eD9F52b28595d31B441D079B2Ca07;
    address public PIDRateSetter_Address = 0x162A433068F51e18b7d13932F27e66a3f99E6890;
    address public AccountingJob_Address = 0xdbC43Ba45381e02825b14322cDdd15eC4B3164E6;
    address public LiquidationJob_Address = 0x04C89607413713Ec9775E14b954286519d836FEf;
    address public OracleJob_Address = 0x4C4a2f8c81640e47606d3fd77B353E87Ba015584;
    address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address = 0x9467A509DA43CB50EB332187602534991Be1fEa4;
    address public CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address = 0x330981485Dbd4EAcD7f14AD4e6A1324B48B09995;
    address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address = 0x7bc9A7e2bDf4c4f6b1Ff8Cff272310a4b17F783d;
    address public CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address = 0x6c615C766EE6b7e69275b0D070eF50acc93ab880;
    address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address = 0x8b89239aca8527bFa52A144faEc4B0EB99052D03;
    address public CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address = 0x04ED4ad3cDe36FE8ba944E3D6CFC54f7Fe6c3C72;
    address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address = 0xf9b42E09Fd787d6864D6b2Cd8E1350fc93E6683D;
    address public CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address = 0x972B2c69B067FFF06fB054f3Ad36210C75792f95;
    address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address = 0xd468bF477c0c99095D508c3B0A60f39348d91ac0;
    address public CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address = 0x06F22B54c2dAbA237DdDC9F10Ee12dCF91CBfCF5;
    address public TimelockController_Address = 0x3347B4d90ebe72BeFb30444C9966B2B990aE9FcB;
    address public ODGovernor_Address = 0x3155755b79aA083bd953911C92705B7aA82a18F9;
    address public Vault721_Address = 0x5bf5b11053e734690269C6B9D438F8C9d48F528A;
    address public ODSafeManager_Address = 0xffa7CA1AEEEbBc30C874d32C7e22F052BbEa0429;
    address public NFTRenderer_Address = 0x3aAde2dCD2Df6a8cAc689EE797591b2913658659;
    address public BasicActions_Address = 0xab16A69A5a8c12C732e0DEFF4BE56A70bb64c926;
    address public DebtBidActions_Address = 0xE3011A37A904aB90C8881a99BD1F6E21401f1522;
    address public SurplusBidActions_Address = 0x1f10F3Ba7ACB61b2F50B9d6DdCf91a6f787C0E82;
    address public CollateralBidActions_Address = 0x457cCf29090fe5A24c19c1bc95F492168C0EaFdb;
    address public PostSettlementSurplusBidActions_Address = 0x525C7063E7C20997BaaE9bDa922159152D0e8417;
    address public GlobalSettlementActions_Address = 0x38a024C0b412B9d1db8BC398140D00F5Af3093D4;
    address public RewardedActions_Address = 0x5fc748f1FEb28d7b76fa1c6B07D8ba2d5535177c;
  // forgefmt: disable-end
}
