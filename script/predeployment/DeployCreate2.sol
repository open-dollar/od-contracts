// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {IODCreate2Factory} from '@interfaces/factories/IODCreate2Factory.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {OpenDollar, SystemCoin, ISystemCoin} from '@contracts/tokens/SystemCoin.sol';

// BROADCAST
// source .env && forge script DeployProtocolTokenMainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployProtocolTokenMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployProtocolTokenMainnet is Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);

  bytes internal _protocolTokenInitCode;
  bytes32 internal _protocolTokenHash;
  address internal _precomputeAddress;
  address internal _protocolToken;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));

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
    IProtocolToken(_protocolToken).mint(vm.envAddress('ARB_SEPOLIA_PC'), 10_000_000 * 1e18);

    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script DeployVault721Mainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployVault721Mainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC
contract DeployVault721Mainnet is Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);

  bytes internal _vault721InitCode;
  bytes32 internal _vault721Hash;
  address internal _precomputeAddress;
  address internal _vault721;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_MAINNET_DEPLOYER_PK'));

    _vault721InitCode = type(Vault721).creationCode;
    _vault721Hash = keccak256(_vault721InitCode);

    emit log_named_bytes32('Vault721 init code hash', _vault721Hash);

    _precomputeAddress = _create2.precomputeAddress(MAINNET_SALT_VAULT721, _vault721Hash);
    emit log_named_address('Vault721 precompute', _precomputeAddress);

    _vault721 = _create2.create2deploy(MAINNET_SALT_VAULT721, _vault721InitCode);
    emit log_named_address('Vault721 deployment', _vault721);

    vm.stopBroadcast();
  }
}
