// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IHaiProxyFactory} from '@interfaces/proxies/IHaiProxyFactory.sol';
import {IHaiProxy} from '@interfaces/proxies/IHaiProxy.sol';
import {Assertions} from '@libraries/Assertions.sol';

import {IHaiProxyRegistry} from '@interfaces/proxies/IHaiProxyRegistry.sol';

/**
 * @title  HaiProxyRegistry
 * @notice This contract is used to deploy and keep track of the user's proxy instances
 * @dev    The registry deploys new proxies using HaiProxyFactory contract
 */
contract HaiProxyRegistry is IHaiProxyRegistry {
  using Assertions for address;

  // --- Data ---

  /// @inheritdoc IHaiProxyRegistry
  mapping(address _owner => IHaiProxy) public proxies;

  /// @inheritdoc IHaiProxyRegistry
  IHaiProxyFactory public factory;

  // --- Init ---

  /**
   * @param  _factory Address of the HaiProxyFactory contract
   */
  constructor(address _factory) {
    factory = IHaiProxyFactory(_factory.assertNonNull());
  }

  // --- Methods ---

  /// @inheritdoc IHaiProxyRegistry
  function build() public returns (address payable _proxy) {
    _proxy = _build(msg.sender);
  }

  /// @inheritdoc IHaiProxyRegistry
  function build(address _owner) public returns (address payable _proxy) {
    _proxy = _build(_owner);
  }

  /// @notice Internal method used to deploy a new proxy instance and store it in the registry
  function _build(address _owner) internal returns (address payable _proxy) {
    // Not allow new _proxy if the user already has one and remains being the owner
    require(proxies[_owner] == IHaiProxy(payable(address(0))) || proxies[_owner].owner() != _owner);
    _proxy = factory.build(_owner);
    proxies[_owner] = IHaiProxy(_proxy);
    emit Build(_owner, _proxy);
  }
}
