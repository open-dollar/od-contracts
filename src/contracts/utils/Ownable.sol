// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOwnable} from '@interfaces/utils/IOwnable.sol';

abstract contract Ownable is IOwnable {
  address public owner;

  // --- Init ---
  constructor(address _owner) {
    _setOwner(_owner);
  }

  function setOwner(address _owner) external onlyOwner {
    _setOwner(_owner);
  }

  // --- Internal ---
  // TODO: make 2-step ownership transfer
  function _setOwner(address _newOwner) internal {
    owner = _newOwner;
    emit SetOwner(_newOwner);
  }

  // --- Modifiers ---
  /**
   * @notice Checks whether msg.sender can call an owned function
   */
  modifier onlyOwner() {
    if (msg.sender != owner) revert OnlyOwner();
    _;
  }
}
