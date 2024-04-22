const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const filePath = path.join(__dirname, "../deployments/anvil/run-latest.json");

fs.readFile(filePath, "utf8", (err, data) => {
  if (err) {
    console.error(err);
    return;
  }
  const dataObj = JSON.parse(data);
  const contracts = dataObj.transactions.reduce((acc, curr, index) => {
    const { contractAddress, contractName, transactionType } = curr;

    if (contractAddress && contractName && transactionType.includes("CREATE")) {
      // Protocol contracts
      let name = contractName;
      if (contractName === "MintableERC20") {
        const tokenSymbolArg = curr.arguments[1].toUpperCase();
        name = name + "_" + tokenSymbolArg.replaceAll('"', "");
      } else if (contractName === "OpenDollarGovernance") {
        name = "ProtocolToken";
      } else if (contractName === "OpenDollar") {
        name = "SystemCoin";
      }
      acc[name] = ethers.getAddress(contractAddress);
    }
    if (curr.additionalContracts.length) {
      let name;
      // Factory children
      curr.additionalContracts.forEach((contract) => {
        if (contract.address && contract.transactionType === "CREATE") {

          if (
            curr.contractName.includes("CollateralAuctionHouseFactory") ||
            curr.contractName.includes("CollateralJoinFactory")
          ) {

            name = curr.contractName.includes("CollateralAuctionHouseFactory") ? "CollateralAuctionHouseChild" : "CollateralJoinChild"

            // Appends the collateral type
            name = name + "_" + curr.arguments[0];
          }
          if (
            curr.contractName.includes("DelayedOracleFactory")
          ) {
            name = "DelayedOracleChild" + "_" + index;
          } else if (curr.contractName.includes("DenominatedOracleFactory")) {
            name = "DenominatedOracleChild" + "_" + index;
          } else if (curr.contractName.includes("RelayerFactory")) {
            name = "RelayerChild" + "_" + index;
          }

          acc[name] = ethers.getAddress(contract.address);
        }
      });
    }
    return acc;
  }, {});
  console.log("Deployment file parsed successfully!");

  createAnvilDeploymentsFile(contracts);
});

const createAnvilDeploymentsFile = (contracts) => {
  const addressText = Object.keys(contracts).reduce((acc, curr) => {
    acc += `  address public ${curr}_Address = ${contracts[curr]};\n`;
    return acc;
  }, "");

  const outputPath = path.join(
    __dirname,
    "../script/anvil/deployment/AnvilContracts.t.sol"
  );
  const content = `// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract AnvilContracts {
${addressText}}
`;

  fs.writeFile(outputPath, content, (err) => {
    if (err) {
      console.error(err);
      return;
    }

    console.log("AnvilContracts.t.sol written to file successfully!");
  });
};
