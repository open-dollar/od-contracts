const fs = require("fs");
const path = require("path");

const [targetEnv, contractName] = process.argv.slice(2);

const target = targetEnv[0].toUpperCase() + targetEnv.slice(1);
let filePath;
if(target == "Sepolia" || target == "Mainnet"){
filePath = path.join(__dirname, `../script/${target}Contracts.s.sol`);
} else if (target == "Anvil"){
filePath = path.join(__dirname, `../script/anvil/deployment/${target}Contracts.t.sol`);
} else {
    console.log("Network not recognized");
    return;
}

const addresses = fs.readFileSync(filePath).toString();


function stringToObject(str) {
    const parts = str.split(';');
    const trimmedArray = {};
    parts.filter((element, i ) => {
        return element.includes('=');
    }).forEach((e,i) => {
        const searchString = 'address public';
        const thing = e.indexOf(searchString);
        const [key, value] = e.trim().slice(thing + 12).split('=');
        const trimmedKey = key.trim().replace(/^address\s+/, '');
        const trimmedValue = value.trim().replace(/;$/, '');
  
   
        trimmedArray[trimmedKey] = trimmedValue;
    })

    return trimmedArray;
  }
const addressObj = stringToObject(addresses)

const keys = Object.keys(addressObj).filter(e => e.toLowerCase().includes(contractName));

if(keys.length == 1){
  const foundAddress = {
    name: keys[0],
    address: addressObj[keys[0]]
  }
  console.log(foundAddress.name, ':', foundAddress.address);
  return JSON.stringify(foundAddress);
} else {
    console.log("Please use a more precise contract name.");
}

