const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
require("dotenv").config();

const args = process.argv.slice(2);
const jsonPath = "../" + args[0];

const basePath = path.join(__dirname, jsonPath);
const currentJson = JSON.parse(fs.readFileSync(basePath));
const network = currentJson.network;

if (currentJson.objectArray != undefined) {
  // create correct number of modifications
  currentJson["arrayLength"] = currentJson.objectArray.length.toString();

  fs.writeFile(basePath, JSON.stringify(currentJson, null, 2), (err) => {
    if (err) {
      console.error(err);
      return;
    }
  });
}

if (currentJson.proposalType == "AddCollateral") {
  const [signer, provider] = getNetwork(network);
  if (signer && provider) {
    predictAddressAndWriteToFile(currentJson, provider);
  } else {
    process.exitCode(2);
  }
}

function getNetwork(network) {
  let signer; //ethers.getCreateAddress(from: , nonce: 1)
  let provider;
  if (network == "anvil") {
    let anvilRpc = process.env.ANVIL_RPC;
    let anvilPK = process.env.ANVIL_ONE;
    provider = new ethers.JsonRpcProvider(anvilRpc, provider);
    signer = new ethers.Wallet(anvilPK, provider);
  } else if (network == "sepolia" || network == "arb-sepolia") {
    const rpc_endpoint = process.env.ARB_SEPOLIA_RPC;
    provider = new ethers.JsonRpcProvider(rpc_endpoint);
    signer = new ethers.Wallet(process.env.ARB_SEPOLIA_PK.slice(2), provider);
  } else if (network == "arb-mainnet" || "mainnet") {
    const rpc_endpoint = process.env.ARB_MAINNET_RPC;
    provider = new ethers.JsonRpcProvider(rpc_endpoint);
    signer = new ethers.Wallet(process.env.ARB_MAINNET_PK.slice(2), provider);
  }
  return [signer, provider];
}

async function predictAddress(currentJson, provider) {

  const contractJSON = JSON.parse(
    fs.readFileSync(
      path.join(__dirname, "../out/GlobalSettlement.sol/GlobalSettlement.json")
    )
  );

  const globalSettlement = new ethers.Contract(
    currentJson.GlobalSettlement_Address,
    contractJSON.abi,
    provider
  );

  const collateralAuctionHouseFactoryAddress =
    await globalSettlement.collateralAuctionHouseFactory();
  const nonce = await provider.getTransactionCount(
    collateralAuctionHouseFactoryAddress
  );
  const predictedAddress = ethers.getCreateAddress({
    from: collateralAuctionHouseFactoryAddress,
    nonce: nonce,
  });
  return predictedAddress;
}

async function predictAddressAndWriteToFile(currentJson, provider) {
  const predictedAddress = await predictAddress(currentJson, provider);
  currentJson["LiquidationEngineCollateralParams"]["newCAHChild"] = predictedAddress;
  fs.writeFileSync(basePath, JSON.stringify(currentJson, null, 2), (err) => {
    if (err) {
      console.error(err);
      return;
    }
  });
}

const proposalType =
  currentJson.proposalType[0].toUpperCase() + currentJson.proposalType.slice(1);

// output desired path.
let desiredPath = `script/gov/Generate/Generate${proposalType}Proposal.s.sol:Generate${proposalType}Proposal`;

console.log(desiredPath);
return;
