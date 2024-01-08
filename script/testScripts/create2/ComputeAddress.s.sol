// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {OpenDollar, SystemCoin, ISystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {OpenDollarGovernance, ProtocolToken, IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

// SIMULATE
// source .env && forge script ComputeAdress --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

/**
 * cast create2 --starts-with FEE --case-sensitive --deployer 0xd7729CC26096035e1A7e834cE0b72599Da25FA7f --init-code-hash 0x2c2da24cf8ff20a033122ffbcaa010c6edbc1b0a17ae658667c45c8b28d54a75
 *  Salt: 0x46320220579d213d0446f6f1fb03407627be45d5215e7d705569a5346288aa97
 *
 * cast create2 --starts-with FEE --case-sensitive --deployer 0xd7729CC26096035e1A7e834cE0b72599Da25FA7f --init-code-hash 0xefe18de3888fd4c30afdd243d43fa8763c95e8ed0faa142f76a67d94062b3c83
 *  Salt: 0x6db6eafed6e80b66085ed36987b1036f4395f56a4afe54cc63e25738438eeebe
 *
 * cast create2 --starts-with FEE --case-sensitive --deployer 0xd7729CC26096035e1A7e834cE0b72599Da25FA7f --init-code-hash 0x72826cfc58dad84e93750b991b5b55307bccd08ec741ca412a5b01a465ac2c65
 *  Salt: 0x2bfa56b0ce602655b440d2aa008f0900d12ef45823378bf9cb8d32eba74439c3
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
