// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IHaiOwnable2Step} from '@interfaces/utils/IHaiOwnable2Step.sol';

import {Ownable2Step, Ownable} from '@openzeppelin/contracts/access/Ownable2Step.sol';

/**
 * @title  HaiOwnable2Step
 * @notice This abstract contract inherits Ownable2Step
 */
abstract contract HaiOwnable2Step is Ownable2Step, IHaiOwnable2Step {
  // --- Overrides ---

  /// @inheritdoc IHaiOwnable2Step
  function owner() public view virtual override(Ownable, IHaiOwnable2Step) returns (address _owner) {
    return super.owner();
  }

  /// @inheritdoc IHaiOwnable2Step
  function pendingOwner() public view virtual override(Ownable2Step, IHaiOwnable2Step) returns (address _pendingOwner) {
    return super.pendingOwner();
  }

  /// @inheritdoc IHaiOwnable2Step
  function renounceOwnership() public virtual override(Ownable, IHaiOwnable2Step) onlyOwner {
    super.renounceOwnership();
  }

  /// @inheritdoc IHaiOwnable2Step
  function transferOwnership(address _newOwner) public virtual override(Ownable2Step, IHaiOwnable2Step) onlyOwner {
    super.transferOwnership(_newOwner);
  }

  /// @inheritdoc IHaiOwnable2Step
  function acceptOwnership() public virtual override(Ownable2Step, IHaiOwnable2Step) {
    super.acceptOwnership();
  }
}
