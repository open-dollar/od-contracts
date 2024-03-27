// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Vault721} from '@contracts/proxies/Vault721.sol';
import {TestODProxy} from '@contracts/for-test/TestODProxy.sol';

contract TestVault721 is Vault721 {
  function _build(address _user) internal override returns (address payable _proxy) {
    if (_proxyRegistry[_user] != address(0)) revert NotWallet();
    _proxy = payable(address(new TestODProxy(_user)));
    _proxyRegistry[_proxy] = _user;
    _userRegistry[_user] = _proxy;
    emit CreateProxy(_user, address(_proxy));
  }
}
