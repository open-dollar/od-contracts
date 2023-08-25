// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

/**
 * @title  HaiProxyFactory
 * @notice This contract is used to deploy new HaiProxy instances
 */
contract HaiProxyFactory {
  // --- Events ---

  /**
   * @notice Emitted when a new proxy is deployed
   * @param  _sender Address of the caller that deployed the proxy
   * @param  _owner Address of the owner of the new proxy
   * @param  _proxy Address of the new proxy
   */
  event Created(address indexed _sender, address indexed _owner, address _proxy);

  // --- Data ---

  /// @notice Mapping of proxy addresses to boolean state
  mapping(address _proxyAddress => bool _exists) public isProxy;

  // --- Methods ---

  /**
   * @notice Deploys a new proxy instance, setting the caller as the owner
   * @return _proxy Address of the new proxy
   */
  function build() external returns (address payable _proxy) {
    _proxy = _build(msg.sender);
  }

  /**
   * @notice Deploys a new proxy instance, setting the specified address as the owner
   * @param  _owner Address of the owner of the new proxy
   * @return _proxy Address of the new proxy
   */
  function build(address _owner) external returns (address payable _proxy) {
    _proxy = _build(_owner);
  }

  /// @notice Internal method used to deploy a new proxy instance
  function _build(address _owner) internal returns (address payable _proxy) {
    _proxy = payable(address(new HaiProxy(_owner)));
    isProxy[_proxy] = true;
    emit Created(msg.sender, _owner, address(_proxy));
  }
}
