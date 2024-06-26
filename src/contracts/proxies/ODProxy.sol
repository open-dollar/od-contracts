// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Address} from '@openzeppelin/utils/Address.sol';

// Open Dollar
// Version 1.7.0

contract ODProxy {
  using Address for address;

  error TargetAddressRequired();
  error TargetCallFailed(bytes _response);
  error OnlyOwner();

  address public immutable OWNER;

  constructor(address _owner) {
    OWNER = _owner;
  }

  /**
   * @notice Checks whether msg.sender can call an owned function
   */
  modifier onlyOwner() {
    if (msg.sender != OWNER) revert OnlyOwner();
    _;
  }

  /**
   * @dev protocol delegatecall function
   */
  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();

    _response = _target.functionDelegateCall(_data);
  }

  /**
   * @dev arbitrary call function
   * @notice prevents erc20 funds from getting stuck in proxy
   */
  function arbitraryExecute(
    address _target,
    bytes memory _data
  ) external payable onlyOwner returns (bytes memory _response) {
    _response = _target.functionCall(_data);
  }
}
