// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {OpenDollar, SystemCoin, ISystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

// SIMULATE
// source .env && forge script ComputeAdress --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

/**
 * NOTE: Deployer is create2Factory
 *
 * systemCoin
 * cast create2 --starts-with 000 --case-sensitive --deployer 0x6EDb251053B4F7670C98e18bbEA20818367b4C0f --init-code-hash 0x2c2da24cf8ff20a033122ffbcaa010c6edbc1b0a17ae658667c45c8b28d54a75
 *
 * protocolToken
 * cast create2 --starts-with 000 --case-sensitive --deployer 0x6EDb251053B4F7670C98e18bbEA20818367b4C0f --init-code-hash 0xefe18de3888fd4c30afdd243d43fa8763c95e8ed0faa142f76a67d94062b3c83
 *
 * vault721
 * cast create2 --starts-with 000 --case-sensitive --deployer 0x6EDb251053B4F7670C98e18bbEA20818367b4C0f --init-code-hash 0x03160121e9b16d692233a05a09dd1d28fa1ddd8ae2398810df6f85940019bfa4
 */
contract ComputeAdress is Script, Test {
  bytes internal _systemTokenInitCode;
  bytes internal _protocolTokenInitCode;
  bytes internal _vault721InitCode;

  bytes32 internal _systemTokenHash;
  bytes32 internal _protocolTokenHash;
  bytes32 internal _vault721Hash;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));

    // initialization code
    _systemTokenInitCode = type(OpenDollar).creationCode;
    _protocolTokenInitCode = type(OpenDollarGovernance).creationCode;
    _vault721InitCode = type(Vault721).creationCode;

    // precompute hashes for create2
    _systemTokenHash = keccak256(_systemTokenInitCode);
    _protocolTokenHash = keccak256(_protocolTokenInitCode);
    _vault721Hash = keccak256(_vault721InitCode);

    emit log_named_bytes32('systemCoin', _systemTokenHash);
    emit log_named_bytes32('protocolToken', _protocolTokenHash);
    emit log_named_bytes32('vault721', _vault721Hash);

    vm.stopBroadcast();
  }
}
