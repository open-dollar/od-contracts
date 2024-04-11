const fs = require("fs");
const path = require("path");

const args = process.argv.slice(2);
const jsonPath = "../" + args[0];

const basePath = path.join(__dirname, jsonPath);

const currentJson = JSON.parse(fs.readFileSync(basePath));

const proposalType = currentJson.proposalType[0].toUpperCase() + currentJson.proposalType.slice(1);

let desiredPath = `script/testScripts/gov/GenerateProposal/Generate${proposalType}Proposal.s.sol:Generate${proposalType}Proposal`

console.log(desiredPath);
return;