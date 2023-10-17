// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x56c03FB820a1e1a220De090A48469c5C5fa41460;
  address public UniV3RelayerFactory_Address = 0x7a5C32479d88fF1e84962D503534cD12da7472b3;
  address public CamelotRelayerFactory_Address = 0x2D8083332E2007f1838c111c00F93002A0B0E365;
  address public DenominatedOracleFactory_Address = 0xa3971FC17cA7720e40E99C320649FFf84b89741f;
  address public DelayedOracleFactory_Address = 0xFD0Db9D944929b589E3584B1C0A97677EE0D07d4;
  address public MintableVoteERC20_Address = 0x15B8D9600B57FEC5dD8bb93b208fC908BA14561f;
  address public MintableERC20_WSTETH_Address = 0xb1C411460D37a6655f12370B17268b276b876176;
  address public MintableERC20_CBETH_Address = 0x884B20bd2A1929090d6085aB375615Ca57D0C34C;
  address public MintableERC20_RETH_Address = 0xDea3A3742ecB96B5e9ABE960b83918c8c0110C1E;
  address public MintableERC20_MAGIC_Address = 0x1A413460DF23D1c7767654DfD956D1e9C0c0A999;
  address public ChainlinkRelayerChild_11_Address = 0xAb085a37cd79602889911310d805C4B3F4937640;
  address public DenominatedOracleChild_13_Address = 0x298fAa62C97bDc79e7421E2f6e88B7d79656Cf40;
  address public DenominatedOracleChild_15_Address = 0xD3A59EAab3B719DAe9931600D463945704a2C8A2;
  address public DenominatedOracleChild_17_Address = 0xDb1E9dfA42198493Bd91BB6a0EfFDc9c718812E9;
  address public DelayedOracleChild_ARB_Address = 0xc235d14517ef38fbAEAE9AE7288c90ED8b8631cC;
  address public DelayedOracleChild_WSTETH_Address = 0xD36c382f06AaDbf0b7C6832438E89bb34e4D0770;
  address public DelayedOracleChild_CBETH_Address = 0x5f0eCfB17Af47E42f19778E100b1cD74de0A2f55;
  address public DelayedOracleChild_RETH_Address = 0x791b6C5B6Cf790C7Eb27873f249963D5c562A02E;
  address public DelayedOracleChild_MAGIC_Address = 0xC13C9627600347C0DA5ff09aA31d795E5096647f;
  address public SystemCoin_Address = 0x9a4D39Efaba9d225947bdC1f2B9386A646F438b2;
  address public ProtocolToken_Address = 0xe6f6B739425a186A1E997B7b50aC60ebFb3EA6ec;
  address public SAFEEngine_Address = 0x32474e5Cf3452DFCc6ca340600cAC1f78C9aF733;
  address public OracleRelayer_Address = 0x379822a342Ba69FaaC82796b5AA76a4Fcf102f18;
  address public SurplusAuctionHouse_Address = 0x74A31029DC0dAC158faBEC4a71cEd26E1C8B32BD;
  address public DebtAuctionHouse_Address = 0x2218288df0cB8267a5A82Bb7D48682Bb5550F85D;
  address public AccountingEngine_Address = 0xca5947DB460ee029FcA1Fa73d20e10b9Ed73A6D9;
  address public LiquidationEngine_Address = 0xf224f3d71eB3844C0308056F1D467aa7Bb7b5C83;
  address public CollateralAuctionHouseFactory_Address = 0xDA5f461F3a4dAFA11dE008098A166E3918E9290B;
  address public CoinJoin_Address = 0xacc6511DE4D2aFd081624786AA773CF24C736569;
  address public CollateralJoinFactory_Address = 0x78C530a4A35b814158B69Ee2D0a41bB96336E39A;
  address public TaxCollector_Address = 0x1A906C363FBB28999bFE798b037094cF55561f39;
  address public StabilityFeeTreasury_Address = 0x22C78678318E8433B87EA31e49974ec03B64CFd2;
  address public GlobalSettlement_Address = 0x7b3Ded404f7d2AC27A29589A00286257B7C7C039;
  address public PostSettlementSurplusAuctionHouse_Address = 0xd8cfCb82D3f1e27F0A757c45aFA326E9225D37fE;
  address public SettlementSurplusAuctioneer_Address = 0x8758FeD3e23e134C497eFE0E1dF3266e9dC3df42;
  address public PIDController_Address = 0x3836c7F9C7dB0FdB17937Ca7A4E53C29aF09A431;
  address public PIDRateSetter_Address = 0xE07767039234A5ACD6Fd099C1BEdF75f290622b9;
  address public AccountingJob_Address = 0xfd0af2B3Dd4e8CD6D93d60DfE6884718cB043CFF;
  address public LiquidationJob_Address = 0x35e79f312E1341804bd4776de1Bac88AcA586038;
  address public OracleJob_Address = 0x2B57d88681dC10dCdf72Aa38fE5Ac62fD2Cd3CF4;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x0e8e0844B12daA36564E374f1008267AcaA06732;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x573Be2b22aA60E530872b9CAA26B69f2B8e26925;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xd111Ef6e2115194dd8f2F9c1EE0CF94bF876E74c;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xc9b86e6e296d3cdB020923a8Bfd9D0d6909b4411;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x79239DF88c18e69bC71130947A5E9a058aa4Ae21;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x31317e37c605D773FD802627aD8c1Cbed50b2078;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0x79621B953299E2E0637EEb1402EbedF90EDCB765;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x70c669b6aB37A1e0B4C014268c71F86345F80789;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0x8B08724A76FAd747C2FAC457A4F6408B0401d20e;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0x1Ed704ebef80262D78a8B8289940812750D3932C;
  address public TimelockController_Address = 0x8E68B53d0c3d3f4A9bDffD87782949041395019C;
  address public ODGovernor_Address = 0xFefAd2d690895604c8588e4d5bEE31261D06A620;
  address public Vault721_Address = 0x8b68dda01E3c17edeb2fb03c6e390D25b906f8A2;
  address public ODSafeManager_Address = 0xF5Aa4AD994619576A8bD7057Ea4395ea756a66C2;
  address public NFTRenderer_Address = 0xeAEc29151af54D3580b35cb4c961Ec6e2195136b;
  address public BasicActions_Address = 0x74D0fECEf1b9D94Edd966a0a5e22bD5Abc9d31f3;
  address public DebtBidActions_Address = 0x10a473C563b2339499da1374EB18C45C353351eb;
  address public SurplusBidActions_Address = 0x7Df27c06FB8b6525FEaC2756A2d1Cf501240C322;
  address public CollateralBidActions_Address = 0xB5c349C3372Da3fFa5008C1f22f9cA93a25E1335;
  address public PostSettlementSurplusBidActions_Address = 0xd4b027FC2D1b69981862f3ff281c12E53FB06C41;
  address public GlobalSettlementActions_Address = 0x6AA6326FbB0B809e2C862ae645d79e67302C0274;
  address public RewardedActions_Address = 0x5AE91f06F7386b09c25fe67D3C7628B762b53Ee7;
  address public AlgebraChild_Address = 0xe19eB4e06Dec65aa414AeDA2a4f42DE81E14Ec68;
  address public CamelotRelayerChild_127_Address = 0xEb6481E31a0fB065960D1E09A39Dc63EF9Cec34b;
  address public DenominatedOracleChild_OD_Address = 0x829592d44F7Fa6D25562E9642f4670D40B5959e9;
}
