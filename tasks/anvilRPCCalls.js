const { ethers } = require("ethers");

const args = process.argv.slice(2);
const call = args[0];
const arg = args[1]; 
const rpcAddress = args[2];
const provider = new ethers.JsonRpcProvider('http://localhost:8545')

if(call == "anvil_mine"){
provider.send(call, [ethers.toBeHex(arg)]);
}
