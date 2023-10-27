// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x5Fa32DE19BaFD8a38F0A12350086A5B757eCe3F1;
  address public UniV3RelayerFactory_Address = 0x9587C971D16cfbe1411D85BF9Bfb605F250082DC;
  address public CamelotRelayerFactory_Address = 0x5514f4290F24af97d50D3FAd0d7D0dA0c931e618;
  address public DenominatedOracleFactory_Address = 0xae7D17e02c3CDc400715C3aC4dC7E12ead84038E;
  address public DelayedOracleFactory_Address = 0x70f2b7756f315818Cb872693C0ed204a3DCF09A4;
  address public MintableVoteERC20_Address = 0x293271161022c0e238eBbF111d4a8d9EFe03CaED;
  address public MintableERC20_WSTETH_Address = 0xe167FB4b43e177dF231EB8f2cf90694F1cd77C64;
  address public MintableERC20_CBETH_Address = 0xab1aEd4A8e53388c06Ac2b580aDF07FfbC4DBb75;
  address public MintableERC20_RETH_Address = 0xC8da5d0E45a4BbeC38b1617b953bC09F744E5E63;
  address public MintableERC20_MAGIC_Address = 0x6c5caD655942e340B67F1916F79C03b2b10c152C;
  address public ChainlinkRelayerChild_11_Address = 0xb46Fb50A214aC2B0360E4751ec3DC48176D5E495;
  address public DenominatedOracleChild_13_Address = 0x5413B8886eD53D7c1cF2271074754DFdC6443536;
  address public DenominatedOracleChild_15_Address = 0xd1fffB759F0A534703501BbAA79c3060Ea82900e;
  address public DenominatedOracleChild_17_Address = 0x472575592E5d3E0BE9Ed3b99A5BC6914eE403D96;
  address public DelayedOracleChild_ARB_Address = 0x85509032Ab2cE815d7ff5a728d257C874701445E;
  address public DelayedOracleChild_WSTETH_Address = 0xeE9b69C2503A4AF0AEDAE8D8d86Bd42Da8B7C1D6;
  address public DelayedOracleChild_CBETH_Address = 0x3FEEB081eF960D6b68Ac03d8007613c12AA95471;
  address public DelayedOracleChild_RETH_Address = 0xC6eceE8dCf0d107A5C8FdB4a6F73B0B851876596;
  address public DelayedOracleChild_MAGIC_Address = 0x03aD2f91aB7b6f759138C317E7304290Ce7039D1;
  address public SystemCoin_Address = 0x5DDef636F664907681f70245beF86B8Dc9E52b4c;
  address public ProtocolToken_Address = 0xA37C21C89B9800E32f8D66bDfc37C74b36659F28;
  address public TimelockController_Address = 0x523eE15aF4dc34a9894cC7411b00886B236d1926;
  address public ODGovernor_Address = 0xb06d9902103a54B255Dd494dc67ed7819D143B9E;
  address public SAFEEngine_Address = 0x7e9EB173BbA99641cd4B9dEdfea5c3cB5C1De267;
  address public OracleRelayer_Address = 0x8694Ae78fE340fEf5ACF3420612BAF68D91e74DC;
  address public SurplusAuctionHouse_Address = 0x6f2979c27ba11Ed22285e05B464B6519C69218fd;
  address public DebtAuctionHouse_Address = 0x25DE686657b2062faDeEa23B366dF41DB433032e;
  address public AccountingEngine_Address = 0x3A4660c95d07963c114E43aB4783648542c204AC;
  address public LiquidationEngine_Address = 0xC91aEE2Ea24ABdbCc2fBa6062Ed74f5F08f2A3a8;
  address public CollateralAuctionHouseFactory_Address = 0x7cEFEb47Ec24f3484D6CD3deD7C00b08150650Fd;
  address public CoinJoin_Address = 0x7689f0bf5FEc6c9E9e729C54535E683e8Be134b6;
  address public CollateralJoinFactory_Address = 0xa04F8c01e301b7A682B5d3826E63F46A0cD35C68;
  address public TaxCollector_Address = 0x3308D5952bDB235b08a7BeE72209cd35C059a831;
  address public StabilityFeeTreasury_Address = 0x48255fA2619DF0905808db38314743E7F6a0973C;
  address public GlobalSettlement_Address = 0x43787bDB58BFb9C34c889d83754865FDe05F91Bb;
  address public PostSettlementSurplusAuctionHouse_Address = 0xf8fD9626C0d37Fb0Cb0BCC554ffAF23ADce599E7;
  address public SettlementSurplusAuctioneer_Address = 0x44121df6D9Cc1D9644889EB04eD68A7a8910F2F9;
  address public PIDController_Address = 0x2EA7D342EbfaFd10A9DbeE5c04ACbF6e648017a7;
  address public PIDRateSetter_Address = 0xB68e29C1eB7D7BE3195e6B377bd6303458c34B3b;
  address public AccountingJob_Address = 0xB49E6fe3aB936D12F03f66af235353D16728cf56;
  address public LiquidationJob_Address = 0x22BeE25Ec68026c51160c02845381F7395cE9311;
  address public OracleJob_Address = 0xDDbF9973C9C7E5f252EE6F5019a4902c71766caC;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x6c368EE5Ff71cDe42aFc4F4D067E1dAB9E375200;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xd2405258628EDA9db20c3C78549974D4209873D8;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x808B2a327ab8E45547a18fCE813B75Fe2363827e;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x79e72Eee4A096f48c6dfe3D6A9E61E18Ea37EBdF;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x66B7DF4584B43BA02fAa79F6e904CF1a0A07E659;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0xae8678eDCCce8529B4D500C9b9e3B634142b50cC;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xdC90d05101Fc9eb2B10236Bc8EAcEaAc8947eCd6;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x9Fd1E9ee8aC3077054F5f36A5236e9807CF6B307;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0xBcD99909f0876731F2C48e5FC4664c6C79043B09;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0xc515F499fC6aF46093c455fD62996b4aF35B62a6;
  address public Vault721_Address = 0x4472919671dAe5b9A6F42703f77F9211C74B6bB0;
  address public ODSafeManager_Address = 0xE4afB7fE6aeA177697e3B9d6D1c261776187AACb;
  address public NFTRenderer_Address = 0x13b1Bb5202563e7d024410C875196C4833E2EE53;
  address public BasicActions_Address = 0x027cadf2103931d76617D86F0A1Da17004AAA6f0;
  address public DebtBidActions_Address = 0x1c3935725Bbe01D50ffadC1B655b3f1593e268C0;
  address public SurplusBidActions_Address = 0x0f76FBed51Ffa08217529a776A241Fd479542Bc6;
  address public CollateralBidActions_Address = 0x4232E0f52caDC72cC89a055DeC310F296A7826d1;
  address public PostSettlementSurplusBidActions_Address = 0x227F5DEe718984c85931F1c6862749D4C4DaD7A0;
  address public GlobalSettlementActions_Address = 0xB0109f703C1178787dA1e4fFDEC3AAF3714Eeb13;
  address public RewardedActions_Address = 0xf2E8aB48e39c7eB5a3d8af128167068F4CDb0d47;
}
