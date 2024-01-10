// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {IODCreate2Factory} from '@interfaces/factories/IODCreate2Factory.sol';

/**
 * @dev Create2Factory that permits vanity address deployments
 * @notice Prevents frontrunning with access control
 */
contract ODCreate2Factory is Authorizable, IODCreate2Factory {
  constructor() Authorizable(msg.sender) {}

  function precomputeAddress(bytes32 _salt, bytes32 _initCodeHash) external view returns (address _precompute) {
    _precompute = address(uint160(uint256(keccak256(abi.encodePacked(hex'ff', address(this), _salt, _initCodeHash)))));
  }

  function create2deploy(bytes32 _salt, bytes memory _initCode) external isAuthorized returns (address _deployment) {
    _deployment = _deploy(_salt, _initCode);
  }

  function _deploy(bytes32 _salt, bytes memory _initCode) internal returns (address _deployment) {
    assembly {
      _deployment := create2(callvalue(), add(_initCode, 0x20), mload(_initCode), _salt)
      if iszero(extcodesize(_deployment)) { revert(0, 0) }
    }
    emit Deployed(_deployment, _salt);
  }
}
