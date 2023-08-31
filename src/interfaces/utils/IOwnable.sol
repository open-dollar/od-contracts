// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IOwnable {
  // --- Events ---

  /**
   * @notice Emitted when a new contract owner is set
   * @param  _newOwner Address of the new owner
   */
  event SetOwner(address _newOwner);

  // --- Errors ---

  /// @notice Throws if an `onlyOwner` method is called by any account other than the owner
  error OnlyOwner();

  // --- Data ---

  /// @notice Address of the contract owner
  function owner() external view returns (address _owner);

  // --- Admin ---

  /**
   * @notice Sets a new contract owner
   * @param  _newOwner Address of the new owner
   */
  function setOwner(address _newOwner) external;
}
