// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public ChainlinkRelayerFactory_Address = 0x362dD03cc941c823a10B9dfeE23253204ecA0e10;
  address public UniV3RelayerFactory_Address = 0xb1d9D11025bc32e490Fc41A3EcAe0c6e1e17730D;
  address public CamelotRelayerFactory_Address = 0xc9ff715Cc5B90047fB9EeD8Ab0658E3f1B0ceFe9;
  address public DenominatedOracleFactory_Address = 0xBB667e7DAcac9e692067b2489E1f9FD531Cbabba;
  address public DelayedOracleFactory_Address = 0xd569F6cA7c06B19D209D9cAdb28CA4C42cC7eB64;
  address public MintableVoteERC20_Address = 0xF09376A1391A2581c29A315a06B869B2b4b834E3;
  address public MintableERC20_WSTETH_Address = 0xFa065ba6c1d9a4d44DCE8788C5f555c039a95f88;
  address public MintableERC20_CBETH_Address = 0xb9Cf77Bf479E3EC1b606B7a5C519083e504689d6;
  address public MintableERC20_RETH_Address = 0x52E7AeCd39F5d80Cbf6556f3A3905AA3d2f5837d;
  address public MintableERC20_MAGIC_Address = 0x3775854dC472D08dA9BB533a4ac4774BC334D741;
  address public ChainlinkRelayerChild_11_Address = 0x42d8a0Eb0dFE1b5b4A2631adBb3310aEa3d70a92;
  address public DenominatedOracleChild_13_Address = 0xFEAE7C03c5Ed0086f3BA6280ed566303E6cE2dc9;
  address public DenominatedOracleChild_15_Address = 0x3b6954c08d53F71f654c3967c97e2e9b77a14CaE;
  address public DenominatedOracleChild_17_Address = 0xA7E5a9F3b6c6eE0EeCe7c3aAB190A10d6BFEaC7d;
  address public DelayedOracleChild_ARB_Address = 0x5f27F0F75F30a967989d738EcE5533D0B608d117;
  address public DelayedOracleChild_WSTETH_Address = 0xc1330fAa515C88420336392FBe5ca7a3dBDb4fd3;
  address public DelayedOracleChild_CBETH_Address = 0xba410D4BD7fbC19330F6fb1331D0F46686D0Fa59;
  address public DelayedOracleChild_RETH_Address = 0x7089Bd87CA813C07cf3802030754C758B617F83A;
  address public DelayedOracleChild_MAGIC_Address = 0x76a448322dD203f68626b0B2900D310fFBC05eaF;
  address public SystemCoin_Address = 0x8413EB19e42e4D54121B191802Ef06A96eff8640;
  address public ProtocolToken_Address = 0x4d8377090cc95D341A3EBe96b6f0C27288c569f5;
  address public SAFEEngine_Address = 0x99e452Fc2696dbd07Cb0F8A0ff4ECdB9A279d6cc;
  address public OracleRelayer_Address = 0x895327Eb7511FeE4f529bAbC5e733efC5Ac5c4fc;
  address public SurplusAuctionHouse_Address = 0xc3D2378ADA77c65eC51a02bf87b6484D2e74213C;
  address public DebtAuctionHouse_Address = 0xCb8F803f2c19F3FbB5ceB0D1904b81C7D3725040;
  address public AccountingEngine_Address = 0x4815abCa47dE1cf324896d673b002B12aFc8AcEa;
  address public LiquidationEngine_Address = 0xD874b07C2BB5c382bdB3ae53b4cFfbEA2dc56D31;
  address public CollateralAuctionHouseFactory_Address = 0x8a9E54D2c5a4FAb57a32C1f72B3Df68e95451729;
  address public CoinJoin_Address = 0x5aC1efD8eD60Ee5816F2a1eB7F64F06B93583feC;
  address public CollateralJoinFactory_Address = 0x0C648D73170eDeb27CD544b6CAcFe5ee9e96347e;
  address public TaxCollector_Address = 0x95fFd6E1537dB0F3b78b8Ba539BFAbc3822A07aD;
  address public StabilityFeeTreasury_Address = 0x57cD616049db6Acde1c056AA6Cb7577ea522E5F9;
  address public GlobalSettlement_Address = 0x68b8043ABafA7d9B396b424c1EA0599A61c9665d;
  address public PostSettlementSurplusAuctionHouse_Address = 0x69E89b5c0CB5991beAA6196783090D2eEcF0214e;
  address public SettlementSurplusAuctioneer_Address = 0x15703A4a27057E9d8DCA4ec9Cc989806a9498073;
  address public PIDController_Address = 0x2125fC0c2B8c8a2DDEdd45F7d02bB53DDD001DD5;
  address public PIDRateSetter_Address = 0xC06eAbB9835E271ee3A16496BF5AfB06b866B6EC;
  address public AccountingJob_Address = 0x126d412c13af2C0134A3D30AC04f6A66C3F743ed;
  address public LiquidationJob_Address = 0x1C4B9a28A70d268AC611D7fFC758361030AbCE08;
  address public OracleJob_Address = 0x5F7E9273E256e0519c7F28ed1C13F6c0A5b70610;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x624543DAa75ee98CB26477a1eB24E5521D1DfFd5;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0xc66dC4D0c0A50c2BF221635957Df4f647C6ccFbd;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x113CfdeEFe78588402FEcee311Dabe8f1C16BB6E;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xBaeF4f78F9db83EDF33D59DeDAfa6821610493bC;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x3E564C613F0F7EBa0837fc8389D41FE9F1576b46;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x563229D4B0dEf7bb04b0d5D5Fa65Be0A9658140a;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xcDA1e0865877026D7be8B1187AC37A8c9145Ba7E;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0xCeCB53B46A92aAd14e6ab3791000A24f105f6099;
  address public CollateralJoinChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
    0x329A880153959f0aE50Eb49954Dc02B133fc9887;
  address public
    CollateralAuctionHouseChild_0x4d41474943000000000000000000000000000000000000000000000000000000_Address =
      0x11da3b8a7c2aF0E1945720C7bfeEF0C44Cc86301;
  address public TimelockController_Address = 0xd7403d96B6Aa921e8D9ce02252D1CDC432d5C5f9;
  address public ODGovernor_Address = 0xe0dd90C2d83becCA665B7A7D34a75FC154EDD6F3;
  address public Vault721_Address = 0xA37a57f71D32ed476B34f32009f1A075fEfDf5Eb;
  address public ODSafeManager_Address = 0xDF8748628D41EF17cba8508D93a859CBeAA3c0D6;
  address public NFTRenderer_Address = 0xd746E6f33507D5a9F4892b1D2A4EEFb1B32A9f03;
  address public BasicActions_Address = 0x6c00d87eE3dB3a5cF40e1214c80Fc616091EDdFB;
  address public DebtBidActions_Address = 0x206e39496fc7cb539c3D585AeF36d25214c0bFa5;
  address public SurplusBidActions_Address = 0x2bf3374879F6CBdbE9CabB9604EFC176792646dd;
  address public CollateralBidActions_Address = 0x5D814Bf578de5Fd3E900b6Cb754d40E6d0526f78;
  address public PostSettlementSurplusBidActions_Address = 0x26092d0E737210B49407C2Cfef06dC7ea35E579f;
  address public GlobalSettlementActions_Address = 0x6A188434C6C4B5BF4405c715513BA552d2b76067;
  address public RewardedActions_Address = 0x2a6dF745eb344f68FBF8Af699391383e9D71Ffa4;
  address public AlgebraChild_Address = 0x5F4e66355409b93e50cf5F30BC03bBD6f111c5Ff;
  address public CamelotRelayerChild_127_Address = 0xF52b839Be8c8952B9aae10e1Fa00692304Cc93Ec;
  address public DenominatedOracleChild_OD_Address = 0x3ef81356f3cF8074cb804084ac48fB7E4C94fe95;
}
