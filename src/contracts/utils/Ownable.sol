// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOwnable} from '@interfaces/utils/IOwnable.sol';

/**
 * @title  Ownable
 * @notice This abstract contract adds basic ownership control functionalities
 */
abstract contract Ownable is IOwnable {
  // --- Data ---

  /// @inheritdoc IOwnable
  address public owner;

  // --- Init ---

  /**
   * @param  _owner The address of the owner of the contract
   */
  constructor(address _owner) {
    _setOwner(_owner);
  }

  /// @inheritdoc IOwnable
  function setOwner(address _owner) external onlyOwner {
    _setOwner(_owner);
  }

  // --- Internal ---

  /// @notice Sets a new contract owner
  function _setOwner(address _newOwner) internal {
    owner = _newOwner;
    emit SetOwner(_newOwner);
  }

  // --- Modifiers ---

  /// @notice Checks whether msg.sender can call an owned function
  modifier onlyOwner() {
    if (msg.sender != owner) revert OnlyOwner();
    _;
  }
}
