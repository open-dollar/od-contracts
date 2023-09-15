const fs = require("fs");
const path = require("path");

const filePath = path.join(__dirname, "../script/GoerliContracts.s.sol");

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

  // VERIFY!!!
  const ETH_ADDRESS = "0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f";

  const final = {
    MULTICALL: "0xcA11bde05977b3631167028862bE2a173976CA11",
    ETH: ETH_ADDRESS,
    GEB_SYSTEM_COIN: parsed.SystemCoinAddr,
    GEB_PROTOCOL_TOKEN: parsed.ProtocolTokenAddr,
    GEB_SAFE_ENGINE: parsed.SAFEEngineAddr,
    GEB_ORACLE_RELAYER: parsed.OracleRelayerAddr,
    GEB_SURPLUS_AUCTION_HOUSE: parsed.SurplusAuctionHouseAddr,
    GEB_DEBT_AUCTION_HOUSE: parsed.DebtAuctionHouseAddr,
    GEB_COLLATERAL_AUCTION_HOUSE_FACTORY: parsed.CollateralAuctionHouseFactory,
    GEB_ACCOUNTING_ENGINE: parsed.AccountingEngineAddr,
    GEB_LIQUIDATION_ENGINE: parsed.LiquidationEngineAddr,
    GEB_COIN_JOIN: parsed.CoinJoin,
    GEB_COLLATERAL_JOIN_FACTORY: parsed.CollateralJoinFactory,
    GEB_TAX_COLLECTOR: parsed.TaxCollector,
    GEB_STABILITY_FEE_TREASURY: parsed.StabilityFeeTreasury,
    GEB_GLOBAL_SETTLEMENT: parsed.GlobalSettlement,
    GEB_POST_SETTLEMENT_SURPLUS_AUCTION_HOUSE:
      parsed.PostSettlementSurplusAuctionHouse,
    GEB_POST_SETTLEMENT_SURPLUS_AUCTIONEER: parsed.SettlementSurplusAuctioneer,
    GEB_RRFM_SETTER: parsed.PIDRateSetterAddr,
    GEB_RRFM_CALCULATOR: parsed.PIDControllerAddr,
    SAFE_MANAGER: parsed.ODSafeManagerAddr,
    GEB_GLOBAL_SETTLEMENT: parsed.GlobalSettlement,
    PROXY_FACTORY: parsed.Vault721Addr,
    // PROXY_BASIC_ACTIONS: parsed.BasicActionsAddr,
    PROXY_REGISTRY: parsed.Vault721Addr,
    PROXY_DEBT_AUCTION_ACTIONS: parsed.DebtBidActionsAddr,
    PROXY_SURPLUS_AUCTION_ACTIONS: parsed.SurplusBidActionsAddr,
    PROXY_COLLATERAL_AUCTION_ACTIONS: parsed.CollateralBidActionsAddr,
    PROXY_POST_SETTLEMENT_SURPLUS_AUCTION_ACTIONS:
      parsed.PostSettlementSurplusBidActionsAddr,
    // PROXY_GLOBAL_SETTLEMENT_ACTIONS: parsed.GlobalSettlementActions,
    PROXY_REWARDED_ACTIONS: parsed.RewardedActionsAddr,
    JOB_ACCOUNTING: parsed.AccountingJobAddr,
    JOB_LIQUIDATION: parsed.LiquidationJobAddr,
    JOB_ORACLES: parsed.OracleJobAddr,
  };

  const collateral = {
    OD: {
      address: parsed.SystemCoinAddr,
    },
    ODG: {
      address: parsed.ProtocolTokenAddr,
    },
    WETH: {
      address: ETH_ADDRESS,
      collateralJoin: parsed.CollateralJoinChild_WETHAddr,
      collateralAuctionHouse: parsed.CollateralAuctionHouseChild_WETHAddr,
    },
    WBTC: {
      address: parsed.MintableERC20WBTC,
      collateralJoin: parsed.CollateralJoinChild_WBTCAddr,
      collateralAuctionHouse: parsed.CollateralAuctionHouseChild_WBTCAddr,
    },
    FTRG: {
      address: parsed.Erc20ForTestnetFTRG,
      collateralJoin: parsed.CollateralJoinDelegatableChild_FTRGAddr,
      collateralAuctionHouse: parsed.CollateralAuctionHouseChild_FTRGAddr,
    },
    STN: {
      address: parsed.MintableERC20STONES,
      collateralJoin: parsed.CollateralJoinChild_STONESAddr,
      collateralAuctionHouse: parsed.CollateralAuctionHouseChild_STONESAddr,
    },
    TOTEM: {
      address: parsed.MintableERC20TOTEM,
      collateralJoin: parsed.CollateralJoinChild_TOTEMAddr,
      collateralAuctionHouse: parsed.CollateralAuctionHouseChild_TOTEMAddr,
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

  console.log("validating addresses...");
  validate(final);
  console.log("validating collateral...");
  Object.values(collateral).map((collat) => validate(collat));

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
});
