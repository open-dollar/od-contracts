const fs = require("fs");
const path = require("path");


const args = process.argv.slice(2);
const targetEnv = args[0].toLowerCase();
const proposalType = args[1];

const inputPath = path.join(__dirname, `../gov-input/${targetEnv}/new-${proposalType}-prop.json`);

const currentProp = require(inputPath);

currentProp ? console.log(JSON.stringify(currentProp, null, 2)) : console.log('');
return;
