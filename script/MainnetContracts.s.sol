// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract MainnetContracts {
  address public SystemCoin_Address = 0x221A0f68770658C15B525d0F89F5da2baAB5f321;
  address public Vault721_Address = 0x4B3c4a28feFA050d0cfC6C405fB855b9b5506f7b;
  address public ProtocolToken_Address = 0x000D636bD52BFc1B3a699165Ef5aa340BEA8939c;
  address public TimelockController_Address = 0x7A528eA3E06D85ED1C22219471Cf0b1851943903;
  address public ODGovernor_Address = 0xf704735CE81165261156b41D33AB18a08803B86F;
  address public DelayedOracleFactory_Address = 0x9Dd63fA54dEfd8820BCAb3e3cC39aeEc1aE88098;
  address public DelayedOracleChild_ARB_Address = 0xa4e0410E7eb9a02aa9C0505F629d01890c816A77;
  address public DelayedOracleChild_WSTETH_Address = 0x026d81728a24c0F20A83c9263A455922c70b84aC;
  address public DelayedOracleChild_RETH_Address = 0x9420eFb9808b0ed432Ad5AD41C302bc908FE344f;
  address public SAFEEngine_Address = 0xEff45E8e2353893BD0558bD5892A42786E9142F1;
  address public OracleRelayer_Address = 0x7404fc1F3796748FAE17011b57Fad9713185c1d6;
  address public SurplusAuctionHouse_Address = 0xA18aFB1953648ec7465d536287a015C237927369;
  address public DebtAuctionHouse_Address = 0x5A021f2063bc2D26fd24a632e29587Afe14D30e5;
  address public AccountingEngine_Address = 0x92Bbc105430F96ddB09300A3b94cf77E3538d92c;
  address public LiquidationEngine_Address = 0x17e546dDCE2EA8A74Bd667269457A2e80b309965;
  address public CollateralAuctionHouseFactory_Address = 0x5dc1E86361faC018f24Ae0D1E5eB01D70AB32A82;
  address public CoinJoin_Address = 0xeE4393C6165a416c83756198A56395F48bbf480f;
  address public CollateralJoinFactory_Address = 0xa83c0f1e9eD8E383919Dde0fC90744ae370EB7B3;
  address public TaxCollector_Address = 0xc93F938A95488a03b976A15B20fAcFD52D087fB2;
  address public StabilityFeeTreasury_Address = 0x9C86C719Aa29D426C50Ee3BAEd40008D292b02CF;
  address public GlobalSettlement_Address = 0x1c6B7ab018be82ed6b5c63aE82D9f07bb7B231A2;
  address public PostSettlementSurplusAuctionHouse_Address = 0x9b9ae60c5475c0735125c3Fb42345AAB780a7a2c;
  address public SettlementSurplusAuctioneer_Address = 0x6c70B191Fc602Bd3756F0aB3684662BBfD8599A6;
  address public PIDController_Address = 0x51f0434645Aa8a98cFa9f0fE7b373297a95Fe92C;
  address public PIDRateSetter_Address = 0xBbb7cC351e323f069602B28B3087b5A50Eb9C654;
  address public AccountingJob_Address = 0x724f970b507F120f81130cE3924d738Db08d69f2;
  address public LiquidationJob_Address = 0x667F9a20d887Ff5943CCf6B35944332aDAE7E2ED;
  address public OracleJob_Address = 0xFaD87e9c629c5c8D84eDB3A134fB998AC80995Ee;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x526Afa46F46Fd80BAa7A6CB62169e59309854611;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x42757A0f17CbE17014f7f914c4146AC7D7f44bB4;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xae7Df58bB63b2Db798f85AB7BCACE340d55f6f39;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x0365dFC776851e970bd6269a2862eFc9a6265273;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xC215F3509AFbB303Bf4a20CBFAA5382fad9bEA1D;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x51a423B43101B219a9ECdEC67525896d856186Ec;
  address public ODSafeManager_Address = 0xC2B820BdD4564301561A11119CB4F190D38De465;
  address public NFTRenderer_Address = 0xce1200B260C11eE8c0feF6891cD21e008D614891;
  address public BasicActions_Address = 0x6eBfcE92CF88f4684CEF44989c35910927a42e9C;
  address public DebtBidActions_Address = 0x490CEDC57E1D2409F111C6a6Db75AC6A7Fc45E4a;
  address public SurplusBidActions_Address = 0x8F43FdD337C0A84f0d00C70F3c4E6A4E52A84C7E;
  address public CollateralBidActions_Address = 0xb60772EDb81a143D98c4aB0bD1C671a5E5184179;
  address public PostSettlementSurplusBidActions_Address = 0x2B7F191E4FdCf4E354f344349302BC3E98780044;
  address public GlobalSettlementActions_Address = 0xBB935d412DFab5200D01B1fcaF2aa14Af5b5b2ED;
  address public RewardedActions_Address = 0xD51fD52C5BCC150491d1e629094a3A56B7194096;
  address public CamelotRelayerFactory_Address = 0x36645830479170265A154Acb726780fdaE41A28F;
  address public ChainlinkRelayerFactory_Address = 0x06C32500489C28Bd57c551afd8311Fef20bFaBB5;
  address public DenominatedOracleFactory_Address = 0xBF760b23d2ef3615cec549F22b95a34DB0F8f5CD;
}
