const fs = require("fs");
const path = require("path");

const args = process.argv.slice(2);
const starterPath = args[0];
let jsonPath;
if( starterPath.slice(0, 1) != "/"){
    jsonPath = "../" + starterPath;
} else {
    jsonPath = ".." + starterPath;
}
const basePath = path.join(__dirname, jsonPath);
const currentJson = JSON.parse(fs.readFileSync(basePath));
const trimmedPath = basePath.slice(basePath.indexOf("/gov-"));
console.log(currentJson.network, trimmedPath);

return;