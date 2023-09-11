// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public chainlinkRelayerFactoryAddr = 0xF4D170497F8491FD3bdB31B1c0e9Ed6e3C4c03d6;
  address public uniV3RelayerFactoryAddr = 0xb13cD0cdA3c13c3Da428B694A81c3De4dAca3bFC;
  address public camelotRelayerFactoryAddr = 0xb13cD0cdA3c13c3Da428B694A81c3De4dAca3bFC;
  address public denominatedOracleFactoryAddr = 0x45063443256fb264e8fB464eb6051D29fF2BebE5;
  address public delayedOracleFactoryAddr = 0xc76CC3153CCB9e088566DDB42441840e9c83baC3;

  address public oracleForTestnet1Addr = 0xBAc743bC5F59592D4e6acFF63b3dFc8047879ccF;
  address public oracleForTestnet2Addr = 0x34C1581bA735F96905d8e54B33A9C5c2aCCBe960;
  address public oracleForTestnet3Addr = 0x9C5aF5E2b7cfBA1CB2d8370E56dCe7D25b84293d;
  address public oracleForTestnet4Addr = 0x0136fEeB4a57d1478c002e4e9a5465d48B65d791;

  address public chainlinkRelayerChild1Addr = 0x69204a70Ba01Cb2d14b05DCc26E135d0c7da40DC;
  address public chainlinkRelayerChild2Addr = 0x37462C5A3820280Af0D0671729027cf238C0BE09;

  address public erc20ForTestnetWBTC = 0x734C4c45CEAd4ece4e8640597dD9057066FB297A;
  address public erc20ForTestnetSTONES = 0x67164A419ACD05806eD8ACB98AbC5952168e0e48;
  address public erc20ForTestnetTOTEM = 0x004df384bc4F7Df4f6Ef5aC796F51B422A9f4F5a;

  address public denominatedOracleChild1Addr = 0xbD6d8693206923A1Cd6A96153414577A9a82EFc4;
  address public denominatedOracleChild2Addr = 0xBFE5fbA967aE0e100DAb0FB6E8bC190CF1ce87b1;
  address public denominatedOracleChild3Addr = 0x9e6fbC56c1E782bC3f216199E073FC7a5d255087;

  address public delayedOracleChild1Addr = 0xbFde54d18227FD34ddb7E7980db149186D1c59D7;
  address public delayedOracleChild2Addr = 0xd381C726C0F2eC9f51Cdf3d381d0A54e391cf12F;
  address public delayedOracleChild3Addr = 0x0f255399e1Ce8EB56B623e9152a28Cd2a93EB3DD;
  address public delayedOracleChild4Addr = 0x2aaEd328A3E0E18ef04e92f812064bBA7f9Dc349;
  address public delayedOracleChild5Addr = 0x68e8C56E20e716c069901b6754A6C453c05bC738;

  address public systemCoinAddr = 0x8cDB3a12534cE7b768EA34E3638BBcd82a5E62c4;
  address public protocolTokenAddr = 0x5084b33324B7435f2924F98C7780E41Ba85ad613;

  address public safeEngineAddr = 0x02382F0C54D5ac134eb19E70e9936206361Ed811;

  address public oracleRelayerAddr = 0x05e18e6acD53848f44Cca66Fb3A5CE3D332faC6B;
  address public surplusAuctionHouseAddr = 0x9C0a6A3241D66baa9B8A9696a9b43f7dA97E9FE4;
  address public debtAuctionHouseAddr = 0x10EbCf3989aE2fFf635d383685Cfbb4912908b81;
  address public accountingEngineAddr = 0x47edF7aC52aD57c0228e9630053AaA0E7d4B1C52;
  address public liquidationEngineAddr = 0xda647521328a4cb16067E9c1FD183D0b2B5932d7;

  address public collateralAuctionHouseFactoryAddr = 0x79399Df38Ca64F8B5dDC7B4BAF9322f843cd94AE;
  address public coinJoinAddr = 0xbA3000c3a6E0A78bF4fc51F07eaF08f44152931f;
  address public collateralJoinFactoryAddr = 0x831BF4b9B2E980c87D86cED8681f3da4899FeA5D;

  address public taxCollectorAddr = 0xa464175dDF38d6BD1aaC9079A0152598b87f8a22;
  address public stabilityFeeTreasuryAddr = 0xa92dcA14DD44F6020aF7014Db1C88d5284427C1A;
  address public globalSettlementAddr = 0x2825f41460f1b058Bd3Af6F55ddBa767b3189859;
  address public postSettlementSurplusAuctionHouseAddr = 0x569810B5441B1F5C19D7Ff4A6b4c82b4099E8e4c;
  address public settlementSurplusAuctioneerAddr = 0x55899fd7E880Ce1ff52e6bb27A9293Ee25c32802;

  address public PIDControllerAddr = 0xbb50b13Ca83456A7367d53abCce5B2fA6b060A75;
  address public PIDRateSetterAddr = 0xCd35709Cbd66c6e45B1b9980745998b4eB0128ac;

  address public accountingJobAddr = 0x91B8D5B3d8c3caC621DCfca1A52E6b38851E7Abd;
  address public liquidationJobAddr = 0x0A29E53c0C4Cadee85217F1a54be4944caa4215C;
  address public oracleJobAddr = 0xf607310e749BBF5246BF3bC53AF6a7347A06db79;

  address public collateralJoinChild_WETHAddr = 0xa117dc068dd32b0FFAe064a79Db4533284FA6f9d;
  address public collateralAuctionHouseChild_WETHAddr = 0xfabF242A981A3823033dC203F5a36D5acD500b80;
  address public collateralJoinDelegatableChild_FTRGAddr = 0xaC6637117E773180Aa4Dc096b507dCC6f7D8d8Ec;
  address public collateralAuctionHouseChild_FTRGAddr = 0x786fe878E9b6C30eE8159E62947c5d0326c2a56b;
  address public collateralJoinChild_WBTCAddr = 0x186e21D4DC564f7Cb9d16E3F2Fe7f4afdDA96760;
  address public collateralAuctionHouseChild_WBTCAddr = 0x3ED063c8258c60A76cc491A742Def9910370e5F6;
  address public collateralJoinChild_STONESAddr = 0x44B2148183223B69BdFAe17c47B8B5cC2590Ec7E;
  address public collateralAuctionHouseChild_STONESAddr = 0x3Db2C21f1715944b1524057d3D94B78B6DE403a0;
  address public collateralJoinChild_TOTEMAddr = 0xD140D849D9f112111CD76Dbb7B90b4C6Fd713550;
  address public collateralAuctionHouseChild_TOTEMAddr = 0x52184505951C8608AA4e8Fc124d4cba9d51771ED;

  address public vault721Addr = 0xd4A3c66C306CC1dC38D360ED2020Db3A2e77d13B;
  address public odSafeManagerAddr = 0xe31cC068227e55c5AD15Cb22EbcBE1376a3C5b95;

  address public basicActionsAddr = 0x7667cFc5655Ee7AB2272A12a1A27F7362e3c1343;
  address public debtBidActionsAddr = 0xFf70D914a655d614cF8C20ab32f5c232a46A461F;
  address public surplusBidActionsAddr = 0xDD654683BdcdFCc4577d6516D79517A5D95f3730;
  address public collateralBidActionsAddr = 0xA0D71bdFf0D877ace7C54C16A2FE514A2B98bd8a;
  address public rewardedActionsAddr = 0x40d783a881e57ea9e5d34e746D70E19E1Ff4D5Ce;
  address public globalSettlementActionsAddr = 0x2BE2eE171A647Eec0f69E89B9fa4BD30b6b8Ed98;
  address public postSettlementSurplusBidActionsAddr = 0x18B0256862Db77aBCdA85635f6b7667fD4a609B4;

  address public nftRenderer2Addr = 0x9AE4ED276C90FC9523552642d208e5853035D33E;
}
