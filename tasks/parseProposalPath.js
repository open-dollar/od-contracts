const fs = require("fs");
const path = require("path");

const args = process.argv.slice(2);
const jsonPath = "../" + args[0];

const basePath = path.join(__dirname, jsonPath);
const currentJson = JSON.parse(fs.readFileSync(basePath));

if(currentJson.numberOfModifications != undefined){
// create correct number of modifications
currentJson.numberOfModifications = currentJson.modifyObjects.length;

// write to json
fs.writeFile(basePath, JSON.stringify(currentJson), (err) => {
    if (err) {
      console.error(err);
      return;
    }
});
}

const proposalType = currentJson.proposalType[0].toUpperCase() + currentJson.proposalType.slice(1);

// output desired path.
let desiredPath = `script/testScripts/gov/Generate/Generate${proposalType}Proposal.s.sol:Generate${proposalType}Proposal`

console.log(desiredPath);
return;