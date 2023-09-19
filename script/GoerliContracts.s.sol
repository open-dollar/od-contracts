// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public chainlinkRelayerFactoryAddr = 0x54E21c81B15C85aCA20a82dc7fDfDCc5627b555A;
  address public uniV3RelayerFactoryAddr = 0x09f9C6fdD0f16163BE706aAD070Cd648f35553a9;
  address public camelotRelayerFactoryAddr = 0x665112BAC0E8208F3e2C2cEbf7a90353C53455E7;
  address public denominatedOracleFactoryAddr = 0x0E97683f5AE79DA8adDb37d7b5309046405d8888;
  address public delayedOracleFactoryAddr = 0xe71b919881a1DCeCbC1d176830865dd892CC2B6F;

  address public oracleForTestnet1Addr = 0x790fC3fb54aFF38A66C062B9A9B1C81c355f73DF;
  address public oracleForTestnet2Addr = 0x7490e39ea822817e5d8e7d040Fa399879cb69AbC;
  address public oracleForTestnet3Addr = 0x0f12Dbb82FD0F86F9CfdCa6201E3b6BA1D9c388b;
  address public oracleForTestnet4Addr = 0x6f21dB20334e5B2B12DbDFEF570e60a772ff4670;

  address public chainlinkRelayerChild1Addr = 0x1c100940b9e5FC3d63E4d985022C2945c31f4074;
  address public chainlinkRelayerChild2Addr = 0xa52028365222B5c2Ae25e54CA9B8753Ff85BC82C;

  address public erc20ForTestnetWBTCAddr = 0x701928a3063702B23E6798662d00F10Fd7116836;
  address public erc20ForTestnetSTONESAddr = 0x33534E219A8B6647F2705Cf4026a39D7440fC198;
  address public erc20ForTestnetTOTEMAddr = 0x1fACF79F3CC1cdf1209dd2d54D21342e047ACe44;

  address public denominatedOracleChild1Addr = 0x84682910D7D3704471E0c4e7F1398590Bc0Bf6C1;
  address public denominatedOracleChild2Addr = 0xe8Fee2c75380c8988Bf11bA6CA69a800a15000E8;
  address public denominatedOracleChild3Addr = 0xFAF3FCbF9b516b558a6EE8dA110cddef46B6e1c1;

  address public delayedOracleChild1Addr = 0x8291C8373bAA84Ae9111bE91f9D9Fa0A428e611c;
  address public delayedOracleChild2Addr = 0x36F5dBd375d331861cFBF24cC38Fa592AB249247;
  address public delayedOracleChild3Addr = 0x583100a6C0C74c5873A60bff92dCA764AFF0c689;
  address public delayedOracleChild4Addr = 0x1DE8ed85f4401D7aC5523C93bBfFD2cda374d6a1;
  address public delayedOracleChild5Addr = 0x8CBf77e0514b1ed1e6e04E0B8f87422B2FDcac7C;

  address public systemCoinAddr = 0x08161Abd14EF3Ae0E81326dD8633B2e1E6403C2F;
  address public protocolTokenAddr = 0x9adbc5c28BE1A58943774298448C32c290bEdB7b;

  address public safeEngineAddr = 0xaA8884AA443b6502e6eb5c310c10722faa6A8085;

  address public oracleRelayerAddr = 0xF64707EB9735D0A53b7Fb9d6817D54d38b85f541;
  address public surplusAuctionHouseAddr = 0xB391103094C49be1bBD3feAcDEFECBb8D430B499;
  address public debtAuctionHouseAddr = 0x72435262a034F542c6494891fE24b7D95b9DF506;
  address public accountingEngineAddr = 0x32f6aC759de1d46DA5f06740c82B785254F6DE59;
  address public liquidationEngineAddr = 0xE42ca384D18D00Cda403478CDE2EFcbbba92cAD7;

  address public collateralAuctionHouseFactoryAddr = 0x3AA15f0025C677597Be103A9995356b6e44971C3;
  address public coinJoinAddr = 0xe12078d30A3957b595c33159177fe694BC60a33e;
  address public collateralJoinFactoryAddr = 0x71a444C23094aB2a507de89084c0C6BaA5b14Ccd;

  address public taxCollectorAddr = 0x69e5596D8326cf9D76b0E2627EF48cC7226A7a0E;
  address public stabilityFeeTreasuryAddr = 0x9983156c6B43ec0b0f12f1006C95C4d5AB4CeF57;
  address public globalSettlementAddr = 0x5C95fd5EABcb2877Ae7189eEE6B37F03951D0E11;
  address public postSettlementSurplusAuctionHouseAddr = 0xE070C49AC7B34e48411901DF19Fd0B87785e13E4;
  address public settlementSurplusAuctioneerAddr = 0x794efd84EC84Aa8337f2549DcA4932e8828596bB;

  address public PIDControllerAddr = 0xB5e730fF17252dF2deC5c3a9746e0489520d57b0;
  address public PIDRateSetterAddr = 0x2BBA667853d7d843714542176536271c16DB09bA;

  address public accountingJobAddr = 0x105F50851a7F978c7a46b8F43CA5241Ea9b7Fcd3;
  address public liquidationJobAddr = 0x990B7f4b936afc61AD12b095EEDb06e9A7FCD433;
  address public oracleJobAddr = 0x93A699b8985f2d3b1089f914989b97DBA31c0874;

  address public collateralJoinChild_WETHAddr = 0x99Aa897a5476136EF09C5a1BAE5e7a40c3F4C9f8;
  address public collateralAuctionHouseChild_WETHAddr = 0x280197607D23032be2F872db21e61f2fecb054C5;
  address public collateralJoinDelegatableChild_FTRGAddr = 0xA4EC23CF73Bd226FAd3160EF69Da733F33766ac0;
  address public collateralAuctionHouseChild_FTRGAddr = 0x648956A68819e0A17b986630c7671a427c8E909e;
  address public collateralJoinChild_WBTCAddr = 0x7e4b18F64A0d2a2079f4DA62a447D6E70E950D50;
  address public collateralAuctionHouseChild_WBTCAddr = 0x060Fa690fDd9e6245eF10b8440f01b1F5F299567;
  address public collateralJoinChild_STONESAddr = 0x2342BeDE2e4adBb2e9c727EE1e2f803FC4E21731;
  address public collateralAuctionHouseChild_STONESAddr = 0xAf7bCf642c0fB0835E4a5A659cc49beCEFe3bdA5;
  address public collateralJoinChild_TOTEMAddr = 0x36Aced7C694dD58B84d4f36DB5947757455257F4;
  address public collateralAuctionHouseChild_TOTEMAddr = 0x2658610472FeC58e9e7F6f2525E79bD69AF4E605;

  address public vault721Addr = 0x8F1e9D071d695Cc1B8389F07e1bAb52Ef2b9DaB4;
  address public odSafeManagerAddr = 0xC0D739C7E5CA5078C52C3A62282F2D8Db42eCE95;
  address public nftRendererAddr = 0x3641fCFE1B3c2780561C4f2C7C80e77F5777f38F;

  address public basicActionsAddr = 0x4ABbdAAE5AF35305f2d33a1Ad74474d2a2B8124d;
  address public debtBidActionsAddr = 0x8E0b35234bde46963e8F9e63dDABC1e62f6BbE1c;
  address public surplusBidActionsAddr = 0x206E6f3294b78ccFE8BAba6a1e8865edcabDd864;
  address public collateralBidActionsAddr = 0x18ba620E7CD7A70dc917b8d0c365526DF27f0C3a;
  address public postSettlementSurplusBidActionsAddr = 0xE972E192D88fd17617C7958E97FAAD478719Aabd;
  address public globalSettlementActionsAddr = 0xC7ECB819FE8F6C2D33cecb55980972587ac4572C;
  address public rewardedActionsAddr = 0x5442caC3b5aD95D0EE9eefFDD8b6576c5406DD97;

  address public timelockControllerAddr = 0x6a2AE2Fbfc3D939B50d2D428e391F49293021dbD;
  address public odGovernorAddr = 0xd9f4508b8906a294B83988BE466F0C6733e8Dd7e;

  address public denominatedOracleChildAddr_SYSCOIN = 0x24370d25d2fc581CB37C52fdE18CE0c26ae2B1db; // (OD / WETH) * (ETH / USD)
}
