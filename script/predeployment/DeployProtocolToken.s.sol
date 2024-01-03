// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {SEPOLIA_CREATE2_FACTORY, SEPOLIA_SALT_PROTOCOLTOKEN} from '@script/Registry.s.sol';
import {ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {Create2Factory} from '@contracts/utils/Create2Factory.sol';

// BROADCAST
// source .env && forge script DeployProtocolToken --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolToken --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployProtocolToken is Script {
  Create2Factory create2Factory = Create2Factory(SEPOLIA_CREATE2_FACTORY);

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    address protocolTokenAddress = create2Factory.deployProtocolToken(SEPOLIA_SALT_PROTOCOLTOKEN);
    IProtocolToken protocolToken = IProtocolToken(protocolTokenAddress);
    protocolToken.initialize('Open Dollar Governance', 'ODG');
    vm.stopBroadcast();
  }
}
