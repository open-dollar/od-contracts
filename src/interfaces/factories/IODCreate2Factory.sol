// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

/**
 * Create2 Factory that permits vanity address deployments
 * Prevents frontrunning with access control
 */
interface IODCreate2Factory is IAuthorizable {
  event Deployed(address _contract, bytes32 _salt);

  function precomputeAddress(bytes32 _salt, bytes32 initCodeHash) external returns (address _precompute);

  function create2deploy(bytes32 _salt, bytes memory _initCode) external returns (address _deployment);
}
