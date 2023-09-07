const fs = require("fs");
const path = require("path");

const filePath = path.join(__dirname, "../src/script/GoerliContracts.s.sol");

fs.readFile(filePath, "utf8", (err, data) => {
  if (err) {
    console.error(err);
    return;
  }

  const cleanedString = data
    .replace(/address public /g, "")
    .replace(/;/g, "")
    .replace(/ /g, "");

  // Split the string into lines
  const lines = cleanedString.split("\n");

  // Create an empty object to store the converted values
  const parsed = {};

  // Iterate over each line and populate the output object
  lines.forEach((line) => {
    const [key, value] = line.split("=");
    parsed[key.trim()] = value?.trim();
  });

  const final = {
    MULTICALL: "0xcA11bde05977b3631167028862bE2a173976CA11",
    // VERIFY!!!
    ETH: "0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f",
    GEB_SYSTEM_COIN: parsed.systemCoinAddr,
    GEB_PROTOCOL_TOKEN: parsed.protocolTokenAddr,
    GEB_SAFE_ENGINE: parsed.safeEngineAddr,
    GEB_ORACLE_RELAYER: parsed.oracleRelayerAddr,
    GEB_SURPLUS_AUCTION_HOUSE: parsed.surplusAuctionHouseAddr,
    GEB_DEBT_AUCTION_HOUSE: parsed.debtAuctionHouseAddr,
    GEB_COLLATERAL_AUCTION_HOUSE_FACTORY:
      parsed.collateralAuctionHouseFactoryAddr,
    GEB_ACCOUNTING_ENGINE: parsed.accountingEngineAddr,
    GEB_LIQUIDATION_ENGINE: parsed.liquidationEngineAddr,
    GEB_COIN_JOIN: parsed.coinJoinAddr,
    GEB_COLLATERAL_JOIN_FACTORY: parsed.collateralJoinFactoryAddr,
    GEB_TAX_COLLECTOR: parsed.taxCollectorAddr,
    GEB_STABILITY_FEE_TREASURY: parsed.stabilityFeeTreasuryAddr,
    GEB_GLOBAL_SETTLEMENT: parsed.globalSettlementAddr,
    GEB_POST_SETTLEMENT_SURPLUS_AUCTION_HOUSE:
      parsed.postSettlementSurplusAuctionHouseAddr,
    GEB_POST_SETTLEMENT_SURPLUS_AUCTIONEER:
      parsed.settlementSurplusAuctioneerAddr,
    GEB_RRFM_SETTER: parsed.PIDRateSetterAddr,
    GEB_RRFM_CALCULATOR: parsed.PIDControllerAddr,
    SAFE_MANAGER: parsed.odSafeManagerAddr,
    GEB_GLOBAL_SETTLEMENT: parsed.globalSettlementAddr,
    PROXY_FACTORY: parsed.vault721Addr,
    PROXY_BASIC_ACTIONS: parsed.basicActionsAddr,
    PROXY_REGISTRY: parsed.vault721Addr,
    PROXY_DEBT_AUCTION_ACTIONS: parsed.debtBidActionsAddr,
    PROXY_SURPLUS_AUCTION_ACTIONS: parsed.surplusBidActionsAddr,
    PROXY_COLLATERAL_AUCTION_ACTIONS: parsed.collateralBidActionsAddr,
    PROXY_POST_SETTLEMENT_SURPLUS_AUCTION_ACTIONS:
      parsed.postSettlementSurplusBidActionsAddr,
    PROXY_GLOBAL_SETTLEMENT_ACTIONS: parsed.globalSettlementActionsAddr,
    PROXY_REWARDED_ACTIONS: parsed.rewardedActionsAddr,
    JOB_ACCOUNTING: parsed.accountingJobAddr,
    JOB_LIQUIDATION: parsed.liquidationJobAddr,
    JOB_ORACLES: parsed.oracleJobAddr,
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
  const content = `export default ${JSON.stringify(final, null, 2)}`;
  fs.writeFile(outputPath, content, (err) => {
    if (err) {
      console.error(err);
      return;
    }

    console.log("JSON object written to file successfully!");
  });
});
