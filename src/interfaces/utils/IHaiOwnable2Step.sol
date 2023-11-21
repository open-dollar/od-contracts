// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IHaiOwnable2Step {
  // --- Events ---

  /**
   * @notice Emitted when an ownership transfer is initiated
   * @param _previousOwner Address of the current owner
   * @param _newOwner Address of the new owner
   */
  //event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);

  // --- Errors ---

  /// @notice Throws if the caller account is not authorized to perform an operation
  //error OwnableUnauthorizedAccount(address _account);
  /// @notice Throws if the owner is not a valid owner account
  //error OwnableInvalidOwner(address _owner);

  // --- Data ---

  /// @notice The address of the current owner
  function owner() external view returns (address _owner);

  /// @notice The address of the pending owner
  function pendingOwner() external view returns (address _pendingOwner);

  // --- Admin ---

  /**
   * @notice Leaves the contract without an owner, thereby disabling any functionality that is only available to the owner
   * @dev It will not be possible to call `onlyOwner` functions
   * @dev Can only be called by the current owner
   */
  function renounceOwnership() external;

  /**
   * @notice Starts the ownership transfer of the contract to a new account
   * @dev Replaces the pending transfer if there is one
   * @dev Can only be called by the current owner
   * @param _newOwner The address of the new owner
   */
  function transferOwnership(address _newOwner) external;

  /**
   * @notice Accepts the ownership transfer
   * @dev Can only be called by the current pending owner
   */
  function acceptOwnership() external;
}
