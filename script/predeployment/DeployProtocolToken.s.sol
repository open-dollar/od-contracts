// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {IODCreate2Factory} from '@interfaces/factories/IODCreate2Factory.sol';

// BROADCAST
// source .env && forge script DeployProtocolTokenMain --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolTokenMain --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployProtocolTokenMainnet is Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(CREATE2FACTORY);

  bytes internal _protocolTokenInitCode;
  bytes32 internal _protocolTokenHash;
  address internal _precomputeAddress;
  address internal _protocolToken;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));

    _protocolTokenInitCode = type(OpenDollarGovernance).creationCode;
    _protocolTokenHash = keccak256(_protocolTokenInitCode);

    _precomputeAddress = _create2.precomputeAddress(SEPOLIA_SALT_PROTOCOLTOKEN, _protocolTokenHash);
    emit log_named_address('ODG precompute', _precomputeAddress);

    _protocolToken = _create2.create2deploy(SEPOLIA_SALT_PROTOCOLTOKEN, _protocolTokenInitCode);
    emit log_named_address('ODG deployment', _protocolToken);

    IProtocolToken(_protocolToken).initialize('Open Dollar Governance', 'ODG');

    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployProtocolTokenSepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolTokenSepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployProtocolTokenSepolia is Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(CREATE2FACTORY);

  bytes internal _protocolTokenInitCode;
  bytes32 internal _protocolTokenHash;
  address internal _precomputeAddress;
  address internal _protocolToken;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));

    _protocolTokenInitCode = type(OpenDollarGovernance).creationCode;
    _protocolTokenHash = keccak256(_protocolTokenInitCode);

    _precomputeAddress = _create2.precomputeAddress(SEPOLIA_SALT_PROTOCOLTOKEN, _protocolTokenHash);
    emit log_named_address('ODG precompute', _precomputeAddress);

    _protocolToken = _create2.create2deploy(SEPOLIA_SALT_PROTOCOLTOKEN, _protocolTokenInitCode);
    emit log_named_address('ODG deployment', _protocolToken);

    IProtocolToken(_protocolToken).initialize('Open Dollar Governance', 'ODG');

    vm.stopBroadcast();
  }
}
