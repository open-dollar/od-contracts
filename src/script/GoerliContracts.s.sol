// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public chainlinkRelayerFactoryAddr = 0xdA42325e6A1f9d04c185b7106f1891a3C381609f;
  address public uniV3RelayerFactoryAddr = 0xdBD245B6606a9E4c63a65A7f68280a133E1239C3;
  address public denominatedOracleFactoryAddr = 0x1f7dCc57EF72C5E8467191e419bcD00039650C0b;
  address public delayedOracleFactoryAddr = 0x400175fd17dF66AD817F084B96065679451bAb1d;

  address public chainlinkRelayerChild1Addr = 0xccE63198A655D7245F2516D70EB52Cd9981De39C;
  address public chainlinkRelayerChild2Addr = 0xB8884578E5f9204Aa5837700cbDFB8Fc7850c94D;
  address public oracleRelayerAddr = 0x276f2F3e4A5Ca476Ef018cbe8646A5e00Db2dC32;

  address public oracleForTestnet1Addr = 0xf0c0629A12a55C1A4013De8F917FE19266CCb6ff;
  address public oracleForTestnet2Addr = 0x16E070C39c4E6390586aab322925127962C96307;
  address public oracleForTestnet3Addr = 0xC571F158A02010Ff07a82DAee858136B229c5Baa;
  address public oracleForTestnet4Addr = 0x6810721bc7E88B6908E5aFc17b3e91A0c54498ee;

  address public denominatedOracleChild1Addr = 0x9f5363dECfC1FE4Ca830c9546F7ea0f5D9927CA1; // oracleForTestnet2Addr
  address public denominatedOracleChild2Addr = 0x4F986dA0bFf80332a446ecdA23369f12aDdf6339; // chainlinkRelayerChild2Addr

  address public erc20ForTestnetWBTC = 0xAcFb9e6FD04FE18c56995C8d58C0785042766736;
  address public erc20ForTestnetSTONES = 0x7e6Ee244FA65cEEb8b698E7866E127cD8C7440D0;
  address public erc20ForTestnetTOTEM = 0x0Da1F0E501b20f963Ce671e62E11B09259f714c4;

  address public delayedOracleChild1Addr = 0xdaa81738CdC6B2F771375f49B29648a3F9980cB5; // ETH / USD
  address public delayedOracleChild2Addr = 0xC6b2D74EBbdF6a1fC763e3e0311b73229beA1095; // () * (ETH / USD
  address public delayedOracleChild3Addr = 0x1F6d4ABC8c46A692E399e19c3C2810c6358f605f; // BTC
  address public delayedOracleChild4Addr = 0x447cb167dbDE1B91E84fc2E2c2514cd56b8D9903; // () * (BTC / USD)
  address public delayedOracleChild5Addr = 0x244Cd6BD8367F20a9934BB681a41cfE7010F2489; // empty

  address public systemCoinAddr = 0x007b1aC6B1894351cD5B025470119cf07a719d5b;
  address public protocolTokenAddr = 0x1A095c17f8503A79E754371EfBb232c1C0D9cb07;

  address public safeEngineAddr = 0x3Ea69ED1931929678DE2de8E0b0C8FBd6FA5CFBA;
  address public surplusAuctionHouseAddr = 0x97Ba91F8161c67eC0f5600f96Aa6B78eEcA83E2f;
  address public debtAuctionHouseAddr = 0x73098945f3e73caf01909C957A6bd65ED910F637;

  address public accountingEngineAddr = 0xbeed3E8a9F70A91C5bc5f955B71317C456366CFA;
  address public liquidationEngineAddr = 0xd4E8C2463ac3388ddAC401EC91652190805E375E;

  address public collateralAuctionHouseFactoryAddr = 0x55D542Cb782FcdC9d94a7d007Db8d4B7DdEcEd49;
  address public coinJoinAddr = 0xb340D8890e90AFb7a79f3cFe88Df9E03B4b99b1f;
  address public collateralJoinFactoryAddr = 0x7c0BA91c3eca439Fc4b638e1392DCF8D5E0115ba;

  address public taxCollectorAddr = 0xA290676CED25e26828b00294dBbEebCb356CD2E5;
  address public stabilityFeeTreasuryAddr = 0xf805849c1dE4627ba171F6C93540F77D9B9E6d20;

  address public globalSettlementAddr = 0x472Ec291F772F9FF3D3397553A32EdBfDBd881Ec;
  address public postSettlementSurplusAuctionHouseAddr = 0x40C9110a953c0378e8cD940bd9A9Cfd83840A9f6;
  address public settlementSurplusAuctioneerAddr = 0xf5BCf3Ba14541B60764BbC6BbF3072430Fd18645;

  address public PIDControllerAddr = 0x63F197A871dF1485311762bc3284c2E4f0A65c0b;
  address public PIDRateSetterAddr = 0xb8E0FF656c799A79F08d44dDaf508D343693DE4e;

  address public accountingJobAddr = 0x6Bd60DC7DdC59Dd6859381f82D25D787fc7D6174;
  address public liquidationJobAddr = 0x6FCB78970cA8A026f940C8c1adeEd5Bc1D6Cda4d;
  address public oracleJobAddr = 0x0e0A3d34dB3990F6D1cC42895bfb107a81D29d58;

  address public collateralJoinChild_WETHAddr = 0xd4F5Dc250893cA025603A03d1fe5650D03fA5891;
  address public collateralAuctionHouseChild_WETHAddr = 0x74B840D4B626e9bD174F74eFF8a59dE30Fc03eF9;

  address public collateralJoinDelegatableChild_FTRGAddr = 0x01c9E717B10605163D5B0beB45ab93497C34E77A;
  address public collateralAuctionHouseChild_FTRGAddr = 0xEc467776f0D8FF8FDE41057b8b2D0ed298072edF;

  address public collateralJoinChild_WBTCAddr = 0x32490555704591fF252287E888523bDC0cC42226;
  address public collateralAuctionHouseChild_WBTCAddr = 0xf214ADE436451fbb6909F444efFf7C34C2F2bB92;

  address public collateralJoinChild_STONESAddr = 0xeB8AcA91fc4BcEEc73ee8EE6Bcb3a6608F858bD1;
  address public collateralAuctionHouseChild_STONESAddr = 0x85b35CEF271e6c9653b308b6130142B41d1992B8;

  address public collateralJoinChild_TOTEMAddr = 0xC458429Fc706E4d6eA4852592d4d0F3E19563469;
  address public collateralAuctionHouseChild_TOTEMAddr = 0x50298A8cAFdB116700Ba84189Ca426464fE872d5;

  address public vault721Addr = 0x7e65C1e8161e49Ed414bf0C751e9D6B0E370C4db;
  address public odSafeManagerAddr = 0xE4a203f79b4DEf769E4624387bEF5516AC74e7B8;

  address public basicActionsAddr = 0x3C929D32b85ffF713b15e6d9C3B0D5868B0C9157;
  address public debtBidActionsAddr = 0xAF44D66b9d035a028328c99f0Adb7AB85928724c;
  address public surplusBidActionsAddr = 0x267D4BDf13DaDD3Da7C90074E163c44443505CA5;
  address public collateralBidActionsAddr = 0x92A093f53360ffc42f75f6D00af51E26138725b4;
  address public rewardedActionsAddr = 0xA2C86fBae73C2672ace63a732274a1D4c0FE938F;
  address public globalSettlementActionsAddr = 0x173C75bc966FBF33191919B68fFfC688B91859c8;
  address public postSettlementSurplusBidActionsAddr = 0x3b0156CB12A3eac5Cdb0AbDbE90a32e66fE4AEB1;
}
