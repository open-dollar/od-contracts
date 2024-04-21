// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
  address public DenominatedOracleFactory_Address = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
  address public DelayedOracleFactory_Address = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
  address public MintableVoteERC20_Address = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;
  address public MintableERC20_WSTETH_Address = 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;
  address public MintableERC20_CBETH_Address = 0x0165878A594ca255338adfa4d48449f69242Eb8F;
  address public MintableERC20_RETH_Address = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
  address public DenominatedOracleChild_10_Address = 0xCafac3dD18aC6c6e92c921884f9E4176737C052c;
  address public DenominatedOracleChild_12_Address = 0x9f1ac54BEF0DD2f6f3462EA0fa94fC62300d3a8e;
  address public DenominatedOracleChild_14_Address = 0xbf9fBFf01664500A33080Da5d437028b07DFcC55;
  address public DelayedOracleChild_15_Address = 0x75537828f2ce51be7289709686A69CbFDbB714F1;
  address public DelayedOracleChild_16_Address = 0xE451980132E65465d0a498c53f0b5227326Dd73F;
  address public DelayedOracleChild_17_Address = 0x5392A33F7F677f59e833FEBF4016cDDD88fF9E67;
  address public DelayedOracleChild_18_Address = 0xa783CDc72e34a174CCa57a6d9a74904d0Bec05A9;
  address public SystemCoin_Address = 0x3Aa5ebB10DC797CAC828524e59A333d0A371443c;
  address public ProtocolToken_Address = 0xc6e7DF5E7b4f2A278906862b61205850344D4e7d;
  address public TimelockController_Address = 0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44;
  address public ODGovernor_Address = 0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f;
  address public SAFEEngine_Address = 0x67d269191c92Caf3cD7723F116c85e6E9bf55933;
  address public OracleRelayer_Address = 0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E;
  address public SurplusAuctionHouse_Address = 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690;
  address public DebtAuctionHouse_Address = 0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB;
  address public AccountingEngine_Address = 0x9E545E3C0baAB3E08CdfD552C960A1050f373042;
  address public LiquidationEngine_Address = 0xa82fF9aFd8f496c3d6ac40E2a0F282E47488CFc9;
  address public CollateralAuctionHouseFactory_Address = 0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8;
  address public CoinJoin_Address = 0x851356ae760d987E095750cCeb3bC6014560891C;
  address public CollateralJoinFactory_Address = 0xf5059a5D33d5853360D16C683c16e67980206f36;
  address public TaxCollector_Address = 0x95401dc811bb5740090279Ba06cfA8fcF6113778;
  address public StabilityFeeTreasury_Address = 0x998abeb3E57409262aE5b751f60747921B33613E;
  address public GlobalSettlement_Address = 0x5f3f1dBD7B74C6B46e8c44f98792A1dAf8d69154;
  address public PostSettlementSurplusAuctionHouse_Address = 0xb7278A61aa25c888815aFC32Ad3cC52fF24fE575;
  address public SettlementSurplusAuctioneer_Address = 0xCD8a1C3ba11CF5ECfa6267617243239504a98d90;
  address public PIDController_Address = 0x922D6956C99E12DFeB3224DEA977D0939758A1Fe;
  address public PIDRateSetter_Address = 0x5081a39b8A5f0E35a8D959395a630b68B74Dd30f;
  address public AccountingJob_Address = 0x4C4a2f8c81640e47606d3fd77B353E87Ba015584;
  address public LiquidationJob_Address = 0x21dF544947ba3E8b3c32561399E88B52Dc8b2823;
  address public OracleJob_Address = 0x2E2Ed0Cfd3AD2f1d34481277b3204d807Ca2F8c2;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x55652FF92Dc17a21AD6810Cce2F4703fa2339CAE;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x9467A509DA43CB50EB332187602534991Be1fEa4;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x6DDFF2dF38D87DC8CCDfCFCDFDb3608bc296eD60;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x7bc9A7e2bDf4c4f6b1Ff8Cff272310a4b17F783d;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x73269463D5A325Aca756Ec4dFbAC5F1eb81602C9;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x8b89239aca8527bFa52A144faEc4B0EB99052D03;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x120E77dBF77a6A7B4a3a954d9F540302200BaB69;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0xf9b42E09Fd787d6864D6b2Cd8E1350fc93E6683D;
  address public Vault721_Address = 0x34B40BA116d5Dec75548a9e9A8f15411461E8c70;
  address public ODSafeManager_Address = 0x07882Ae1ecB7429a84f1D53048d35c4bB2056877;
  address public NFTRenderer_Address = 0x22753E4264FDDc6181dc7cce468904A80a363E44;
  address public BasicActions_Address = 0xA7c59f010700930003b33aB25a7a0679C860f29c;
  address public DebtBidActions_Address = 0xfaAddC93baf78e89DCf37bA67943E1bE8F37Bb8c;
  address public SurplusBidActions_Address = 0x276C216D241856199A83bf27b2286659e5b877D3;
  address public CollateralBidActions_Address = 0x3347B4d90ebe72BeFb30444C9966B2B990aE9FcB;
  address public PostSettlementSurplusBidActions_Address = 0x3155755b79aA083bd953911C92705B7aA82a18F9;
  address public GlobalSettlementActions_Address = 0x5bf5b11053e734690269C6B9D438F8C9d48F528A;
  address public RewardedActions_Address = 0xffa7CA1AEEEbBc30C874d32C7e22F052BbEa0429;
}
