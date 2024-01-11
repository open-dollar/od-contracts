// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {IODCreate2Factory} from '@interfaces/factories/IODCreate2Factory.sol';

// BROADCAST
// source .env && forge script DeployProtocolTokenMainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolTokenMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

/**
 * @dev forge script to generate salt
 * ProtocolToken
 * cast create2 --starts-with 00000D6 --case-sensitive --deployer 0x6EDb251053B4F7670C98e18bbEA20818367b4C0f --init-code-hash 0xefe18de3888fd4c30afdd243d43fa8763c95e8ed0faa142f76a67d94062b3c83
 *
 * SystemCoin
 * cast create2 --starts-with 00000D011A5 --case-sensitive --deployer 0x6EDb251053B4F7670C98e18bbEA20818367b4C0f --init-code-hash 0x2c2da24cf8ff20a033122ffbcaa010c6edbc1b0a17ae658667c45c8b28d54a75
 *
 * Vault721
 * cast create2 --starts-with 000005AFE --case-sensitive --deployer 0x6EDb251053B4F7670C98e18bbEA20818367b4C0f --init-code-hash 0x72826cfc58dad84e93750b991b5b55307bccd08ec741ca412a5b01a465ac2c65
 */

contract DeployProtocolTokenMainnet is Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);

  bytes internal _protocolTokenInitCode;
  bytes32 internal _protocolTokenHash;
  address internal _precomputeAddress;
  address internal _protocolToken;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_ADMIN_PK'));

    _protocolTokenInitCode = type(OpenDollarGovernance).creationCode;
    _protocolTokenHash = keccak256(_protocolTokenInitCode);

    _precomputeAddress = _create2.precomputeAddress(MAINNET_SALT_PROTOCOLTOKEN, _protocolTokenHash);
    emit log_named_address('ODG precompute', _precomputeAddress);

    _protocolToken = _create2.create2deploy(MAINNET_SALT_PROTOCOLTOKEN, _protocolTokenInitCode);
    emit log_named_address('ODG deployment', _protocolToken);

    IProtocolToken(_protocolToken).initialize('Open Dollar Governance', 'ODG');
    IProtocolToken(_protocolToken).mint(MAINNET_SAFE, 10_000_000 * 1e18);

    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployProtocolTokenSepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolTokenSepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployProtocolTokenSepolia is Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(TEST_CREATE2FACTORY);

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
    IProtocolToken(_protocolToken).mint(TEST_SAFE, 10_000_000 * 1e18);

    vm.stopBroadcast();
  }
}
