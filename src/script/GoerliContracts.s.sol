// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public chainlinkRelayerFactoryAddr = 0xf67824c9dD65425600639Bb1F18c08368A147c69;
  address public uniV3RelayerFactoryAddr = 0xC2d2F3fcA75D05387DB01214D03B6d1EC5F22e44;
  address public denominatedOracleFactoryAddr = 0x290Fdb5878Ac39C888aB0ebdF07c6d5929F6bf65;
  address public delayedOracleFactoryAddr = 0x76E0D3f31B633dBeDd07ec21Dd2Af389E6A6E6e0;

  address public chainlinkRelayerChild1Addr = 0x9d857365C3D626108436Ea2D9cA1412ff1e01BDe;
  address public chainlinkRelayerChild2Addr = 0x0421670ec2cA922Fd957fE73536A0219Df0c2b2B;
  address public oracleRelayerAddr = 0x6453154B95B74ee7daDE7490D1A6398e94673AF1;

  address public oracleForTestnet1Addr = 0xDe1f24323c99c8C3FDeB13CfeB312ad2F8198200;
  address public oracleForTestnet2Addr = 0x94675A3da7a480A8Ba6AeefC091E7EBaBC18dfE4;
  address public oracleForTestnet3Addr = 0x5593C6F598C58aF21769939c00a6A3dbA35cc4D7;
  address public oracleForTestnet4Addr = 0xa296Fb0Edd683AA9c968bD929E3f9658f06b28F1;

  address public denominatedOracleChild1Addr = 0xEECA09432c8B0381281a0D74EB78C0DC1C8457A4; // oracleForTestnet2Addr
  address public denominatedOracleChild2Addr = 0x2A2b7404e40b8dee435604f6f7f78511FbE05Bd4; // chainlinkRelayerChild2Addr
  address public denominatedOracleChild3Addr = 0x9a513a2ef8d750945e5D84F4b0629456E78eD072;

  address public erc20ForTestnetWBTC = 0x88ABF003c637CEfCf6dBad4B37c78C361F11AaBe;
  address public erc20ForTestnetSTONES = 0x9267Ff63472c3081a0D68d4F64bD708C02196631;
  address public erc20ForTestnetTOTEM = 0x0749bF7b71D7221788070D74367cb7ce17302F73;

  address public delayedOracleChild1Addr = 0x7Ef1B8D43f718ea0882e7d11e96d257Ed30D96d2; // ETH / USD
  address public delayedOracleChild2Addr = 0xE7b90dBEb9c02C0C4c1d5B5Ea11acB1B4d86B580; // () * (ETH / USD
  address public delayedOracleChild3Addr = 0x71DfBcabE3Ec3fC901089D91B19c157f4CFAF5f4; // BTC
  address public delayedOracleChild4Addr = 0x7AFAB1f9Fd247a53ef1FF8a45964C3D96659527E; // () * (BTC / USD)
  address public delayedOracleChild5Addr = 0x69524B9e09c28FC235bAC4e8B741584be7fc3Eeb; // empty

  address public systemCoinAddr = 0x1214fC79f895060fAA48e3CAf0C212E3D48B9696;
  address public protocolTokenAddr = 0xC6d32056a6AF761c6ecAA2CC89A82e140a9a6774;

  address public safeEngineAddr = 0x04b4A62152DaB552f976461bA7a490349a72Fe66;

  address public surplusAuctionHouseAddr = 0x6eB5E0973a0159ba07821681034836660bC9AEbf;
  address public debtAuctionHouseAddr = 0x8E4baFC67aA2C3DaA621a566560F3fb1492A43fA;
  address public accountingEngineAddr = 0x86507aA80324D3a739F9349742b42f1966E7fD5A;
  address public liquidationEngineAddr = 0xba72145909Fd2AF2763322902fBc8CFa2593Ddc9;

  address public collateralAuctionHouseFactoryAddr = 0x3bB21228dfb7617f2851e859C118dc2A9FB65c90;
  address public coinJoinAddr = 0x0d730679d360bE6Aaed68B1CdDe618302175bdb0;
  address public collateralJoinFactoryAddr = 0x8c01992a71491EC9C167F3d87D83471926583232;

  address public taxCollectorAddr = 0xa0A2A6beA8F1BaAdfC4d4CCC516A4a784333f74A;
  address public stabilityFeeTreasuryAddr = 0x68837a35eF213dE47221F1Af26c4C60896432825;

  address public globalSettlementAddr = 0x8A77C343E5348399E93926c89782b6c38776C6E0;
  address public postSettlementSurplusAuctionHouseAddr = 0x593B822C8aeA7F09225F8555Dd74Aa439FCb2Cf2;
  address public settlementSurplusAuctioneerAddr = 0x7768284827bc13ADe18040e0aA0437f49AA394Bd;

  address public PIDControllerAddr = 0xeD332e3FB53f7274D596c9987bb5fB0012f66e35;
  address public PIDRateSetterAddr = 0x7D9f230DC1f2a51f3865d81e0E6Af9eB506F0c49;

  address public accountingJobAddr = 0x10BE006CCE05b29B4EfFC89C009db837A6Ad903f;
  address public liquidationJobAddr = 0x58343Bc4e0764d404Ec1d8ED188d50317C27BE84;
  address public oracleJobAddr = 0x55E38c1f7989601eAF23Dfac65EC9b7258a0FD01;

  address public collateralJoinChild_WETHAddr = 0xa20c5ccA3F18E70c7FD809f7098AFf56191933d3;
  address public collateralAuctionHouseChild_WETHAddr = 0xD0C02DE939A2f5e75136712bF086fa5E670561aA;

  address public collateralJoinDelegatableChild_FTRGAddr = 0x164B2A0A50b4e1e8862BE3b7cd1e55296175338b;
  address public collateralAuctionHouseChild_FTRGAddr = 0x529A477914262992FEef9D5cAcA436d4cF2b7d6E;

  address public collateralJoinChild_WBTCAddr = 0x7681f45446677fee1f0aF741d37bA37e50d42c2c;
  address public collateralAuctionHouseChild_WBTCAddr = 0x81Bbe0eafD37483Ec692D506BbAAC50c6f68b435;

  address public collateralJoinChild_STONESAddr = 0x350fB5ad175c54Efe53B97a3608D4B28DB1db5eC;
  address public collateralAuctionHouseChild_STONESAddr = 0xB2662b6636267284Ca8eb09041D66cf11fc040A8;

  address public collateralJoinChild_TOTEMAddr = 0x7670cCe4f1e33Ff43658631bB99A6493BD08ec9F;
  address public collateralAuctionHouseChild_TOTEMAddr = 0x1d792Ab81E5f73F0a0C1750a2bd347FE1d13E2C2;

  address public vault721Addr = 0x8B7b43d4439732794f9a859EaDf83ceF2FeB0C1e;
  address public odSafeManagerAddr = 0x2F365eB51495C3730C0928aE863d8f711c4a89dd;

  address public basicActionsAddr = 0xF7A2663c9D07153eF88d489952396752d19fB689;
  address public debtBidActionsAddr = 0x714bed2FE18fbD8637ac0578f2E983096E785b28;
  address public surplusBidActionsAddr = 0xeeB25da60F3F9C7D8fd9094d3e68C5a49e2441E8;
  address public collateralBidActionsAddr = 0x840Ba7107B739c7936f35f6f8070AB3a12bF00A0;
  address public rewardedActionsAddr = 0x987b7F8330e2f167C4f3e43bfD94f122942d645c;
  address public globalSettlementActionsAddr = 0xc258E9217a38aff39001e1b768710a0D4ac440cD;
  address public postSettlementSurplusBidActionsAddr = 0x1C465a2aC0362306A5a130be59409C4aCCab4636;
}
