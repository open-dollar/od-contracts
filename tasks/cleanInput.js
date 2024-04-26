const fs = require("fs");
const path = require("path");

const args = process.argv.slice(2);
const basePath = args[0];

const currentJson = JSON.parse(fs.readFileSync(basePath));

const contractNames = Object.keys(currentJson).filter((key) => key.includes("_Address"));
let modifiedJson = currentJson;

contractNames.forEach((e) => { modifiedJson[e] = ""});

fs.writeFile(basePath, JSON.stringify(modifiedJson), (err) => {
    if (err) {
      console.error(err);
      return;
    }
  });