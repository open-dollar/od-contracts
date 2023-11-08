// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IHaiProxy} from '@interfaces/proxies/IHaiProxy.sol';

import {HaiOwnable2Step, IHaiOwnable2Step} from '@contracts/utils/HaiOwnable2Step.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';

/**
 * @title  HaiProxy
 * @notice This contract is an ownable proxy to execute batched transactions in the protocol contracts
 * @dev    The proxy executes a delegate call to an Actions contract, which have the logic to execute the batched transactions
 */
contract HaiProxy is HaiOwnable2Step, IHaiProxy {
  using Address for address;

  // --- Init ---

  /**
   * @param  _owner The owner of the proxy contract
   */
  constructor(address _owner) Ownable(_owner) {}

  // --- Methods ---

  /// @inheritdoc IHaiProxy
  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();
    _response = _target.functionDelegateCall(_data);
  }

  // --- Overrides ---

  /// @inheritdoc IHaiOwnable2Step
  function owner() public view override(HaiOwnable2Step, IHaiOwnable2Step) returns (address _owner) {
    return super.owner();
  }

  /// @inheritdoc IHaiOwnable2Step
  function pendingOwner() public view override(HaiOwnable2Step, IHaiOwnable2Step) returns (address _pendingOwner) {
    return super.pendingOwner();
  }

  /// @inheritdoc IHaiOwnable2Step
  function renounceOwnership() public override(HaiOwnable2Step, IHaiOwnable2Step) onlyOwner {
    super.renounceOwnership();
  }

  /// @inheritdoc IHaiOwnable2Step
  function transferOwnership(address _newOwner) public override(HaiOwnable2Step, IHaiOwnable2Step) onlyOwner {
    super.transferOwnership(_newOwner);
  }

  /// @inheritdoc IHaiOwnable2Step
  function acceptOwnership() public override(HaiOwnable2Step, IHaiOwnable2Step) {
    super.acceptOwnership();
  }
}
