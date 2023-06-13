// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Ownable} from '@contracts/utils/Ownable.sol';

contract HaiProxy is Ownable {
  constructor(address _owner) Ownable(_owner) {}

  function execute(address _target, bytes memory _data) public payable onlyOwner returns (bytes memory _response) {
    require(_target != address(0), 'ds-proxy-target-address-required');

    // call contract in current context
    assembly {
      let _succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
      let size := returndatasize()

      _response := mload(0x40)
      mstore(0x40, add(_response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
      mstore(_response, size)
      returndatacopy(add(_response, 0x20), 0, size)

      switch iszero(_succeeded)
      case 1 {
        // throw if delegatecall failed
        revert(add(_response, 0x20), size)
      }
    }
  }
}
