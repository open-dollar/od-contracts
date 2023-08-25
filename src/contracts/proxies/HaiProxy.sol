// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Ownable} from '@contracts/utils/Ownable.sol';

/**
 * @title  HaiProxy
 * @notice This contract is an ownable proxy to execute batched transactions in the protocol contracts
 * @dev    The proxy executes a delegate call to an Actions contract, which have the logic to execute the batched transactions
 */
contract HaiProxy is Ownable {
  // --- Errors ---

  /// @notice Throws if the target address is null
  error TargetAddressRequired();

  /**
   * @notice Throws if the target call fails
   * @param  _response The error response log of the target call
   */
  error TargetCallFailed(bytes _response);

  // --- Init ---

  /**
   * @param  _owner The owner of the proxy contract
   */
  constructor(address _owner) Ownable(_owner) {}

  // --- Methods ---

  /**
   * @notice Executes a call to the target contract through a delegate call
   * @param  _target Address of the target Actions contract
   * @param  _data Encoded data of the transaction to execute
   * @return _response The raw response of the target call
   * @dev    The proxy will call the target through a delegate call (the target must not be a direct protocol contract)
   */
  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();

    bool _succeeded;
    (_succeeded, _response) = _target.delegatecall(_data);

    if (!_succeeded) {
      revert TargetCallFailed(_response);
    }
  }
}
