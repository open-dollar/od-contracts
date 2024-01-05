// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IImmutableCreate2Factory {
  function findCreate2AddressViaHash(bytes32 salt, bytes32 initCodeHash) external returns (address);

  function safeCreate2(bytes32 salt, bytes calldata initCode) external returns (address);
}
