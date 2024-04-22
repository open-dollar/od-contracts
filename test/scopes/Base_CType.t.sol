// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title  Base_CType
 * @notice Abstract contract containing the collateral type to be used in the tests
 * @dev    Used to override it with different implementations (e.g. ETH_A, WSTETH)
 */
abstract contract Base_CType {
  function _cType() internal virtual returns (bytes32);
}
