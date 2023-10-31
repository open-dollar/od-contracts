// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IDisableable is IAuthorizable {
  // --- Events ---

  /// @notice Emitted when the inheriting contract is disabled
  event DisableContract();

  // --- Errors ---

  /// @notice Throws when trying to call a `whenDisabled` method when the contract is enabled
  error ContractIsEnabled();
  /// @notice Throws when trying to call a `whenEnabled` method when the contract is disabled
  error ContractIsDisabled();
  /// @notice Throws when trying to disable a contract that cannot be disabled
  error NonDisableable();

  // --- Data ---

  /**
   * @notice Check if the contract is enabled
   * @return _contractEnabled True if the contract is enabled
   */
  function contractEnabled() external view returns (bool _contractEnabled);

  // --- Methods ---

  /**
   * @notice External method to trigger the contract disablement
   * @dev    Triggers an internal call to `_onContractDisable` virtual method
   */
  function disableContract() external;
}
