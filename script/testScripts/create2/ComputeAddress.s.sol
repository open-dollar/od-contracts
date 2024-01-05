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
 * cast create2 --starts-with Ee --case-sensitive --deployer 0x0000000000FFe8B47B3e2130213B802212439497 --init-code-hash 0xb63cfab7a9c21abc42571f66816b7d04f6bd96a073dd4ef41995194704a1aa16
 *  Salt: 0x55ca6eab76452ad01a1b57da3930a40e6eb0c98a443019ad3f3287e92135402c
 *
 * cast create2 --starts-with Ee --case-sensitive --deployer 0x0000000000FFe8B47B3e2130213B802212439497 --init-code-hash 0xf3adb12de73883f0c3f27e7596047ea0b549c639c5c52ad624c3699a076a4cf4
 *  Salt: 0x676de0f064dab04d9b641255bb12594a0b439684e86ce66c48c04ed7538eac0d
 *
 * cast create2 --starts-with Ee --case-sensitive --deployer 0x0000000000FFe8B47B3e2130213B802212439497 --init-code-hash 0x116585d0edb7b9ab31e3a545a04ea02b5fa424a6d0384dc6d53fbac1270ed60c
 *  Salt: 0xe4df04175c9ff860a4d5af833116a9641719d2ce9335630dc330cc99ddfda488
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
