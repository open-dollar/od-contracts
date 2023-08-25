// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiProxyFactory} from '@contracts/proxies/HaiProxyFactory.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  HaiProxyRegistry
 * @notice This contract is used to deploy and keep track of the user's proxy instances
 * @dev    The registry deploys new proxies using HaiProxyFactory contract
 */
contract HaiProxyRegistry {
  using Assertions for address;

  // --- Data ---

  /// @notice Mapping of user addresses to proxy instances
  mapping(address _owner => HaiProxy) public proxies;

  /// @notice Address of the proxy factory
  HaiProxyFactory public factory;

  // --- Events ---

  /**
   * @notice Emitted when a new proxy is deployed
   * @param  _usr Address of the owner of the new proxy
   * @param  _proxy Address of the new proxy
   */
  event Build(address _usr, address _proxy);

  // --- Init ---

  /**
   * @param  _factory Address of the HaiProxyFactory contract
   */
  constructor(address _factory) {
    factory = HaiProxyFactory(_factory.assertNonNull());
  }

  // --- Methods ---

  /**
   * @notice Deploys a new proxy instance, setting the caller as the owner
   * @return _proxy Address of the new proxy
   */
  function build() public returns (address payable _proxy) {
    _proxy = _build(msg.sender);
  }

  /**
   * @notice Deploys a new proxy instance, setting the specified address as the owner
   * @param  _owner Address of the owner of the new proxy
   * @return _proxy Address of the new proxy
   */
  function build(address _owner) public returns (address payable _proxy) {
    _proxy = _build(_owner);
  }

  /// @notice Internal method used to deploy a new proxy instance and store it in the registry
  function _build(address _owner) internal returns (address payable _proxy) {
    // Not allow new _proxy if the user already has one and remains being the owner
    require(proxies[_owner] == HaiProxy(payable(address(0))) || proxies[_owner].owner() != _owner);
    _proxy = factory.build(_owner);
    proxies[_owner] = HaiProxy(_proxy);
    emit Build(_owner, _proxy);
  }
}
