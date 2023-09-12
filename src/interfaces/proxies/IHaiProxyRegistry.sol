// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IHaiProxy} from '@interfaces/proxies/IHaiProxy.sol';
import {IHaiProxyFactory} from '@interfaces/proxies/IHaiProxyFactory.sol';

interface IHaiProxyRegistry {
  // --- Events ---

  /**
   * @notice Emitted when a new proxy is deployed
   * @param  _usr Address of the owner of the new proxy
   * @param  _proxy Address of the new proxy
   */
  event Build(address _usr, address _proxy);

  // --- Data ---

  /// @notice Mapping of user addresses to proxy instances
  function proxies(address _owner) external view returns (IHaiProxy _proxy);

  /// @notice Address of the proxy factory
  function factory() external view returns (IHaiProxyFactory _factory);

  // --- Methods ---

  /**
   * @notice Deploys a new proxy instance, setting the caller as the owner
   * @return _proxy Address of the new proxy
   */
  function build() external returns (address payable _proxy);

  /**
   * @notice Deploys a new proxy instance, setting the specified address as the owner
   * @param  _owner Address of the owner of the new proxy
   * @return _proxy Address of the new proxy
   */
  function build(address _owner) external returns (address payable _proxy);
}
