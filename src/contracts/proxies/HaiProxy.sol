// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Ownable} from '@contracts/utils/Ownable.sol';

contract HaiProxy is Ownable {
  error TargetAddressRequired();
  error TargetCallFailed(bytes _response);

  constructor(address _owner) Ownable(_owner) {}

  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();

    bool _succeeded;
    (_succeeded, _response) = _target.delegatecall(_data);

    if (!_succeeded) {
      revert TargetCallFailed(_response);
    }
  }
}
