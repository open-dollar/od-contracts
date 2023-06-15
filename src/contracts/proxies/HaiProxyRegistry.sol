// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiProxyFactory} from '@contracts/proxies/HaiProxyFactory.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract HaiProxyRegistry {
  using Assertions for address;

  mapping(address _owner => HaiProxy) public proxies;
  HaiProxyFactory public factory;

  // --- Events ---
  event Build(address _usr, address _proxy);

  constructor(address _factory) {
    factory = HaiProxyFactory(_factory.assertNonNull());
  }

  // deploys a new proxy instance
  // sets owner of proxy to caller
  function build() public returns (address payable _proxy) {
    _proxy = _build(msg.sender);
  }

  // deploys a new proxy instance
  // sets custom owner of proxy
  function build(address _owner) public returns (address payable _proxy) {
    _proxy = _build(_owner);
  }

  function _build(address _owner) internal returns (address payable _proxy) {
    // Not allow new _proxy if the user already has one and remains being the owner
    require(proxies[_owner] == HaiProxy(payable(address(0))) || proxies[_owner].owner() != _owner);
    _proxy = factory.build(_owner);
    proxies[_owner] = HaiProxy(_proxy);
    emit Build(_owner, _proxy);
  }
}
