const fs = require("fs");
const path = require("path");

const args = process.argv.slice(2);
const jsonPath = "../" + args[0];

const basePath = path.join(__dirname, jsonPath);
const currentJson = JSON.parse(fs.readFileSync(basePath));

function stringToObject(str) {
  const parts = str.split(";");
  const trimmedArray = {};
  parts
    .filter((element, i) => {
      return element.includes("=");
    })
    .forEach((e, i) => {
      const searchString = "address public";
      const thing = e.indexOf(searchString);
      const [key, value] = e
        .trim()
        .slice(thing + 12)
        .split("=");
      const trimmedKey = key.trim().replace(/^address\s+/, "");
      const trimmedValue = value.trim().replace(/;$/, "");

      trimmedArray[trimmedKey] = trimmedValue;
    });

  return trimmedArray;
}

function findAddress(currentJson) {
  const target =
    currentJson.network.slice(0, 1).toUpperCase() +
    currentJson.network.slice(1);

  if (target == "Sepolia" || target == "Mainnet") {
    filePath = path.join(__dirname, `../script/${target}Contracts.s.sol`);
  } else if (target == "Anvil") {
    filePath = path.join(
      __dirname,
      `../script/anvil/deployment/${target}Contracts.s.sol`
    );
  } else {
    console.log("Network not recognized");
    return;
  }
  const contractNames = Object.keys(currentJson)
    .filter((key) => key.includes("_Address"))
    .map((e) => e.toLowerCase());
  const addresses = fs.readFileSync(filePath).toString();
  const addressObj = stringToObject(addresses);
  const foundkeys = Object.keys(addressObj).filter((e) => {
    return contractNames.includes(e.toLowerCase());
  });

  if (foundkeys.length > 0) {
    foundkeys.forEach((key) => {
      currentJson[key] = addressObj[key];
    });

    fs.writeFile(basePath, JSON.stringify(currentJson, null, 2), (err) => {
      if (err) {
        console.error(err);
        return;
      }
    });
    return;
  } else {
    console.log("Please use a more precise contract name.");
    return;
  }
}

findAddress(currentJson);
