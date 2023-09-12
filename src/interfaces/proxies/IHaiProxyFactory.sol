// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IHaiProxyFactory {
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
  function isProxy(address _proxyAddress) external view returns (bool _exists);

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
