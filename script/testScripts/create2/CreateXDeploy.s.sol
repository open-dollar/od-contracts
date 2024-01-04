// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {ICreateX} from '@createx/ICreateX.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

// BROADCAST
// source .env && forge script CreateXDeploy --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script CreateXDeploy --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract CreateXDeploy is Script, Test {
  ICreateX internal _createx = ICreateX(CREATEX);

  bytes32 internal _salt;
  bytes internal _protocolToken;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));

    _salt = bytes32(block.timestamp);
    _protocolToken = type(OpenDollarGovernance).creationCode;

    address protocolToken = _createx.deployCreate2(_salt, _protocolToken);
    emit log_named_address('OpenDollarGovernance', protocolToken);

    vm.stopBroadcast();
  }
}
