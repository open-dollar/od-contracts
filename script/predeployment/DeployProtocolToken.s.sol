// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {ICreateX} from '@createx/ICreateX.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

// BROADCAST
// source .env && forge script DeployProtocolTokenMainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolTokenMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployProtocolTokenMainnet is Script {
  ICreateX internal _createx = ICreateX(CREATEX);
  bytes internal _protocolTokenInitCode;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));

    _protocolTokenInitCode = type(OpenDollarGovernance).creationCode;
    IProtocolToken protocolToken =
      IProtocolToken(_createx.deployCreate2(bytes32(MAINNET_SALT_PROTOCOLTOKEN), _protocolTokenInitCode));
    protocolToken.initialize('Open Dollar Governance', 'ODG');

    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployProtocolTokenSepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolTokenSepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployProtocolTokenSepolia is Script {
  ICreateX internal _createx = ICreateX(CREATEX);
  bytes internal _protocolTokenInitCode;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));

    _protocolTokenInitCode = type(OpenDollarGovernance).creationCode;
    IProtocolToken protocolToken =
      IProtocolToken(_createx.deployCreate2(bytes32(SEPOLIA_SALT_PROTOCOLTOKEN), _protocolTokenInitCode));
    protocolToken.initialize('Open Dollar Governance', 'ODG');

    vm.stopBroadcast();
  }
}
