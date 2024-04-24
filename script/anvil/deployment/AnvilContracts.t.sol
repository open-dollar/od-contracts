// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0x01c1DeF3b91672704716159C9041Aeca392DdFfb;
  address public DenominatedOracleFactory_Address = 0x02b0B4EFd909240FCB2Eb5FAe060dC60D112E3a4;
  address public DelayedOracleFactory_Address = 0x638A246F0Ec8883eF68280293FFE8Cfbabe61B44;
  address public OracleForTestnet_Address = 0xefc1aB2475ACb7E60499Efb171D173be19928a05;
  address public MintableVoteERC20_Address = 0xFD6F7A6a5c21A3f503EBaE7a473639974379c351;
  address public MintableERC20_WSTETH_Address = 0xa6e99A4ED7498b3cdDCBB61a6A607a4925Faa1B7;
  address public MintableERC20_CBETH_Address = 0x5302E909d1e93e30F05B5D6Eea766363D14F9892;
  address public MintableERC20_RETH_Address = 0x0ed64d01D0B4B655E410EF1441dD677B695639E7;
  address public DenominatedOracleChild_10_Address = 0xB0aB982AfFE3a403F1dA85B37025368B732B2D91;
  address public DenominatedOracleChild_12_Address = 0x4178E0278413e1C915B1406694eF89396c891590;
  address public DenominatedOracleChild_14_Address = 0x4e94cc6c29171Cd25Cc0beFCf82eFe090Dab20C1;
  address public DelayedOracleChild_15_Address = 0xd1891dD9DFF0784baa1dEb361dDFCAa5aE49cc6F;
  address public DelayedOracleChild_16_Address = 0xF2AdAad89d56D49C697B9907C7D66ef27d96f859;
  address public DelayedOracleChild_17_Address = 0xAF465448967EcFB90856fCBAD13CBE1dfdEd5F2B;
  address public DelayedOracleChild_18_Address = 0x8ED2e41276e2BA5B9D219a2D25fA5DaD838B91B2;
  address public SystemCoin_Address = 0xB377a2EeD7566Ac9fCb0BA673604F9BF875e2Bab;
  address public ProtocolToken_Address = 0x66F625B8c4c635af8b74ECe2d7eD0D58b4af3C3d;
  address public TimelockController_Address = 0xefAB0Beb0A557E452b398035eA964948c750b2Fd;
  address public ODGovernor_Address = 0xaca81583840B1bf2dDF6CDe824ada250C1936B4D;
  address public SAFEEngine_Address = 0xddE78e6202518FF4936b5302cC2891ec180E8bFf;
  address public OracleRelayer_Address = 0xB06c856C8eaBd1d8321b687E188204C1018BC4E5;
  address public SurplusAuctionHouse_Address = 0xaB7B4c595d3cE8C85e16DA86630f2fc223B05057;
  address public DebtAuctionHouse_Address = 0xAD523115cd35a8d4E60B3C0953E0E0ac10418309;
  address public AccountingEngine_Address = 0x045857BDEAE7C1c7252d611eB24eB55564198b4C;
  address public LiquidationEngine_Address = 0x2b5A4e5493d4a54E717057B127cf0C000C876f9B;
  address public CollateralAuctionHouseFactory_Address = 0x413b1AfCa96a3df5A686d8BFBF93d30688a7f7D9;
  address public CoinJoin_Address = 0x02df3a3F960393F5B349E40A599FEda91a7cc1A7;
  address public CollateralJoinFactory_Address = 0x821f3361D454cc98b7555221A06Be563a7E2E0A6;
  address public TaxCollector_Address = 0x1780bCf4103D3F501463AD3414c7f4b654bb7aFd;
  address public StabilityFeeTreasury_Address = 0x5133BBdfCCa3Eb4F739D599ee4eC45cBCD0E16c5;
  address public GlobalSettlement_Address = 0x54B8d8E2455946f2A5B8982283f2359812e815ce;
  address public PostSettlementSurplusAuctionHouse_Address = 0xf090f16dEc8b6D24082Edd25B1C8D26f2bC86128;
  address public SettlementSurplusAuctioneer_Address = 0xd9140951d8aE6E5F625a02F5908535e16e3af964;
  address public PIDController_Address = 0x2625760C4A8e8101801D3a48eE64B2bEA42f1E96;
  address public PIDRateSetter_Address = 0xFE5f411481565fbF70D8D33D992C78196E014b90;
  address public AccountingJob_Address = 0x7B4f352Cd40114f12e82fC675b5BA8C7582FC513;
  address public LiquidationJob_Address = 0xcE0066b1008237625dDDBE4a751827de037E53D2;
  address public OracleJob_Address = 0x82EdA215Fa92B45a3a76837C65Ab862b6C7564a8;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0x2B7d753d31605AB6767F1891562e693596a9Eb14;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x26399c7901De0ed8bd158f91D17c2b77F5F1f6F9;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0xd3F124976dB9217A447451FC2715bbAcEC5F968c;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0xC835B85841b7ACa8C2a9D91d22D3984eCd1daEC6;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0x1203C402E2373cc1f33AFA054012Ab72bd72D94F;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x3cc457c990FAe4079eEc6281F2afA0e48A7232b1;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xA6db428C41a2De2485CAD5d0DF2dfBe9d2d90a95;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x71F9F1762C6Dc119D4961Cbfd99057B563FaB4f9;
  address public Vault721_Address = 0x01E21d7B8c39dc4C764c19b308Bd8b14B1ba139E;
  address public ODSafeManager_Address = 0x1343248Cbd4e291C6979e70a138f4c774e902561;
  address public NFTRenderer_Address = 0x22a9B82A6c3D2BFB68F324B2e8367f346Dd6f32a;
  address public BasicActions_Address = 0x547382C0D1b23f707918D3c83A77317B71Aa8470;
  address public DebtBidActions_Address = 0x7C8BaafA542c57fF9B2B90612bf8aB9E86e22C09;
  address public SurplusBidActions_Address = 0x0a17FabeA4633ce714F1Fa4a2dcA62C3bAc4758d;
  address public CollateralBidActions_Address = 0x5e6CB7E728E1C320855587E1D9C6F7972ebdD6D5;
  address public PostSettlementSurplusBidActions_Address = 0x79E8AB29Ff79805025c9462a2f2F12e9A496f81d;
  address public GlobalSettlementActions_Address = 0x0Dd99d9f56A14E9D53b2DdC62D9f0bAbe806647A;
  address public RewardedActions_Address = 0xeAd789bd8Ce8b9E94F5D0FCa99F8787c7e758817;
}
