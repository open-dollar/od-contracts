const fs = require("fs");
const path = require("path");

const filePath = path.join(__dirname, "../deployments/sepolia/run-latest.json");

fs.readFile(filePath, "utf8", (err, data) => {
  if (err) {
    console.error(err);
    return;
  }
  const dataObj = JSON.parse(data);
  const contracts = dataObj.transactions.reduce((acc, curr, index) => {
    const { contractAddress, contractName, transactionType } = curr;
    if (contractAddress && contractName && transactionType === "CREATE") {
      // Protocol contracts
      let name = contractName;
      if (["MintableERC20", "MintableVoteERC20"].includes(contractName)) {
        const tokenSymbolArg = curr.arguments[1].toUpperCase();
        name = name + "_" + tokenSymbolArg.replaceAll('"', "");
      }
      acc[name] = contractAddress;
    }
    if (curr.additionalContracts.length) {
      // Factory children
      curr.additionalContracts.forEach((contract) => {
        if (contract.address && contract.transactionType === "CREATE") {
          let contractName = curr.contractName.replace("Factory", "Child");
          if (
            curr.contractName === "CollateralAuctionHouseFactory" ||
            curr.contractName == "CollateralJoinFactory"
          ) {
            // Appends the collateral type
            contractName = contractName + "_" + curr.arguments[0];
          }

          if (
            curr.contractName === "DelayedOracleFactory" ||
            curr.contractName === "DenominatedOracleFactory" ||
            curr.contractName.includes("RelayerFactory")
          ) {
            contractName = contractName + "_" + index;
          }

          acc[contractName] = contract.address;
        }
      });
    }
    return acc;
  }, {});
  console.log("Deployment file parsed successfully!");

  createSepoliaDeploymentsFile(contracts);
});

const createSepoliaDeploymentsFile = (contracts) => {
  const addressText = Object.keys(contracts).reduce((acc, curr) => {
    acc += `  address public ${curr}_Address = ${contracts[curr]};\n`;
    return acc;
  }, "");

  const outputPath = path.join(__dirname, "../script/SepoliaContracts.s.sol");
  const content = `// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

abstract contract SepoliaContracts {
${addressText}}
`;

  fs.writeFile(outputPath, content, (err) => {
    if (err) {
      console.error(err);
      return;
    }

    console.log("SepoliaContracts.s.sol written to file successfully!");
  });
};
