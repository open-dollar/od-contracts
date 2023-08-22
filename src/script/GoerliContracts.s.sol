// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
  address public chainlinkRelayerFactoryAddr = address(0);
  address public uniV3RelayerFactoryAddr = address(0);
  address public denominatedOracleFactoryAddr = address(0);
  address public delayedOracleFactoryAddr = address(0);

  address public chainlinkRelayerChild1Addr = address(0);
  address public chainlinkRelayerChild2Addr = address(0);
  address public oracleRelayerAddr = address(0);

  address public oracleForTestnet1Addr = address(0);
  address public oracleForTestnet2Addr = address(0);
  address public oracleForTestnet3Addr = address(0);
  address public oracleForTestnet4Addr = address(0);

  address public denominatedOracleChild1Addr = address(0); // oracleForTestnet2Addr
  address public denominatedOracleChild2Addr = address(0); // chainlinkRelayerChild2Addr

  address public erc20ForTestnetWBTC = address(0);
  address public erc20ForTestnetSTONES = address(0);
  address public erc20ForTestnetTOTEM = address(0);

  address public delayedOracleChild1Addr = address(0); // ETH / USD
  address public delayedOracleChild2Addr = address(0); // () * (ETH / USD
  address public delayedOracleChild3Addr = address(0); // BTC
  address public delayedOracleChild4Addr = address(0); // () * (BTC / USD)
  address public delayedOracleChild5Addr = address(0); // empty

  address public systemCoinAddr = address(0);
  address public protocolTokenAddr = address(0);

  address public safeEngineAddr = address(0);
  address public surplusAuctionHouseAddr = address(0);
  address public debtAuctionHouseAddr = address(0);

  address public accountingEngineAddr = address(0);
  address public liquidationEngineAddr = address(0);

  address public collateralAuctionHouseFactoryAddr = address(0);
  address public coinJoinAddr = address(0);
  address public collateralJoinFactoryAddr = address(0);

  address public taxCollectorAddr = address(0);
  address public stabilityFeeTreasuryAddr = address(0);

  address public globalSettlementAddr = address(0);
  address public postSettlementSurplusAuctionHouseAddr = address(0);
  address public settlementSurplusAuctioneerAddr = address(0);

  address public PIDControllerAddr = address(0);
  address public PIDRateSetterAddr = address(0);

  address public accountingJobAddr = address(0);
  address public liquidationJobAddr = address(0);
  address public oracleJobAddr = address(0);

  address public collateralJoinChild_WETHAddr = address(0);
  address public collateralAuctionHouseChild_WETHAddr = address(0);

  address public collateralAuctionHouseChild_OPAddr = address(0);
  address public collateralJoinDelegatableChild_OPAddr = address(0);

  address public collateralJoinChild_WBTCAddr = address(0);
  address public collateralAuctionHouseChild_WBTCAddr = address(0);

  address public collateralJoinChild_STONESAddr = address(0);
  address public collateralAuctionHouseChild_STONESAddr = address(0);

  address public collateralJoinChild_TOTEMAddr = address(0);
  address public collateralAuctionHouseChild_TOTEMAddr = address(0);

  address public vault721Addr = address(0);
  address public haiSafeManagerAddr = address(0);

  address public basicActionsAddr = address(0);
  address public debtBidActionsAddr = address(0);
  address public surplusBidActionsAddr = address(0);
  address public collateralBidActionsAddr = address(0);
  address public rewardedActionsAddr = address(0);
  address public globalSettlementActionsAddr = address(0);
  address public postSettlementSurplusBidActionsAddr = address(0);
}
