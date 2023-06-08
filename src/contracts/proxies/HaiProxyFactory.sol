// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

contract HaiProxyFactory {
  event Created(address indexed _sender, address indexed _owner, address _proxy);

  mapping(address => bool) public isProxy;

  // deploys a new proxy instance
  // sets owner of proxy to caller
  function build() external returns (address payable _proxy) {
    _proxy = _build(msg.sender);
  }

  // deploys a new_ proxy instance
  // sets custom owner of proxy
  function build(address _owner) external returns (address payable _proxy) {
    _proxy = _build(_owner);
  }

  function _build(address _owner) internal returns (address payable _proxy) {
    _proxy = payable(address(new HaiProxy(_owner)));
    isProxy[_proxy] = true;
    emit Created(msg.sender, _owner, address(_proxy));
  }
}
