const fs = require("fs");
const path = require("path");

const filePath = path.join(__dirname, "../deployments/run-latest.json");

fs.readFile(filePath, "utf8", (err, data) => {
  if (err) {
    console.error(err);
    return;
  }
  const dataObj = JSON.parse(data);
  const contracts = dataObj.transactions.reduce((acc, curr) => {
    const { contractAddress, contractName, transactionType } = curr;
    if (contractAddress && contractName && transactionType === "CREATE") {
      acc[contractName] = contractAddress;
    }
    return acc;
  }, {});
  console.log("Deployment file parsed successfully!");

  createGoerliDeploymentsFile(contracts);
  createOutputFile(contracts);
});

const createGoerliDeploymentsFile = (contracts) => {
  const addressText = Object.keys(contracts).reduce((acc, curr) => {
    acc += `    address public ${curr} = ${contracts[curr]}\n`;
    return acc;
  }, "");

  const outputPath = path.join(__dirname, "../script/GoerliContracts.s.sol");
  const content = `// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliContracts {
${addressText}
}`;

  fs.writeFile(outputPath, content, (err) => {
    if (err) {
      console.error(err);
      return;
    }

    console.log("JSON object written to file successfully!");
  });
};

const createOutputFile = (contracts) => {
  // VERIFY!!!
  const ETH_ADDRESS = "0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f";

  const final = {
    MULTICALL: "0xcA11bde05977b3631167028862bE2a173976CA11",
    ETH: ETH_ADDRESS,
    GEB_SYSTEM_COIN: contracts.SystemCoin,
    GEB_PROTOCOL_TOKEN: contracts.ProtocolToken,
    GEB_SAFE_ENGINE: contracts.SAFEEngine,
    GEB_ORACLE_RELAYER: contracts.OracleRelayer,
    GEB_SURPLUS_AUCTION_HOUSE: contracts.SurplusAuctionHouse,
    GEB_DEBT_AUCTION_HOUSE: contracts.DebtAuctionHouse,
    GEB_COLLATERAL_AUCTION_HOUSE_FACTORY:
      contracts.CollateralAuctionHouseFactory,
    GEB_ACCOUNTING_ENGINE: contracts.AccountingEngine,
    GEB_LIQUIDATION_ENGINE: contracts.LiquidationEngine,
    GEB_COIN_JOIN: contracts.CoinJoin,
    GEB_COLLATERAL_JOIN_FACTORY: contracts.CollateralJoinFactory,
    GEB_TAX_COLLECTOR: contracts.TaxCollector,
    GEB_STABILITY_FEE_TREASURY: contracts.StabilityFeeTreasury,
    GEB_GLOBAL_SETTLEMENT: contracts.GlobalSettlement,
    GEB_POST_SETTLEMENT_SURPLUS_AUCTION_HOUSE:
      contracts.PostSettlementSurplusAuctionHouse,
    GEB_POST_SETTLEMENT_SURPLUS_AUCTIONEER:
      contracts.SettlementSurplusAuctioneer,
    GEB_RRFM_SETTER: contracts.PIDRateSetter,
    GEB_RRFM_CALCULATOR: contracts.PIDController,
    SAFE_MANAGER: contracts.ODSafeManager,
    GEB_GLOBAL_SETTLEMENT: contracts.GlobalSettlement,
    PROXY_FACTORY: contracts.Vault721,
    PROXY_BASIC_ACTIONS: contracts.BasicActions,
    PROXY_REGISTRY: contracts.Vault721,
    PROXY_DEBT_AUCTION_ACTIONS: contracts.DebtBidActions,
    PROXY_SURPLUS_AUCTION_ACTIONS: contracts.SurplusBidActions,
    PROXY_COLLATERAL_AUCTION_ACTIONS: contracts.CollateralBidActions,
    PROXY_POST_SETTLEMENT_SURPLUS_AUCTION_ACTIONS:
      contracts.PostSettlementSurplusBidActions,
    PROXY_GLOBAL_SETTLEMENT_ACTIONS: contracts.GlobalSettlementActions,
    PROXY_REWARDED_ACTIONS: contracts.RewardedActions,
    JOB_ACCOUNTING: contracts.AccountingJob,
    JOB_LIQUIDATION: contracts.LiquidationJob,
    JOB_ORACLES: contracts.OracleJob,
  };

  const collateral = {
    OD: {
      address: contracts.SystemCoin,
    },
    ODG: {
      address: contracts.ProtocolToken,
    },
    WETH: {
      address: ETH_ADDRESS,
      collateralJoin: contracts.CollateralJoinChild_WETH,
      collateralAuctionHouse: contracts.CollateralAuctionHouseChild_WETH,
    },
    WBTC: {
      address: contracts.Erc20ForTestnetWBTC,
      collateralJoin: contracts.CollateralJoinChild_WBTC,
      collateralAuctionHouse: contracts.CollateralAuctionHouseChild_WBTC,
    },
    FTRG: {
      address: contracts.Erc20ForTestnetFTRG,
      collateralJoin: contracts.CollateralJoinDelegatableChild_FTRG,
      collateralAuctionHouse: contracts.CollateralAuctionHouseChild_FTRG,
    },
    STN: {
      address: contracts.Erc20ForTestnetSTONES,
      collateralJoin: contracts.CollateralJoinChild_STONES,
      collateralAuctionHouse: contracts.CollateralAuctionHouseChild_STONES,
    },
    TOTEM: {
      address: contracts.Erc20ForTestnetTOTEM,
      collateralJoin: contracts.CollateralJoinChild_TOTEM,
      collateralAuctionHouse: contracts.CollateralAuctionHouseChild_TOTEM,
    },
  };
  const validate = (obj) => {
    const missing = Object.values(obj).reduce((acc, curr, i) => {
      if (!curr) {
        acc.push(Object.keys(obj)[i]);
      }
      return acc;
    }, []);
    if (missing.length) throw `Missing values: ${missing.join(", ")}`;
  };

  validate(final);

  const outputPath = path.join(__dirname, "./output.js");
  const content = `// WARNING: You must verify the ETH address is still correct 
// which is used in both 'addresses' and 'collateral'


const addresses = ${JSON.stringify(final, null, 2)}
  
const collateral = ${JSON.stringify(collateral, null, 2)}`;

  fs.writeFile(outputPath, content, (err) => {
    if (err) {
      console.error(err);
      return;
    }

    console.log("JSON object written to file successfully!");
  });
};
