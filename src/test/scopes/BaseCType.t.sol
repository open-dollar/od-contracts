// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/**
 * @title  BaseCType
 * @notice Abstract contract containing the collateral type to be used in the tests
 * @dev    Used to override it with different implementations (e.g. ETH_A, WSTETH)
 */
abstract contract BaseCType {
  function _cType() internal virtual returns (bytes32);
}