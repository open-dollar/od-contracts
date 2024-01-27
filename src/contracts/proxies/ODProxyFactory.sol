// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// Open Dollar Version 1.5.9

import './ODProxy.sol';

/**
 * @title ODProxyFactory
 * @notice Factory contract for deploying ODProxy instances using CREATE2
 */
contract ODProxyFactory {
  error zeroLength();

  event ProxyCreated(address indexed owner, address indexed proxy);

  /**
   * @notice Creates a single ODProxy instance using CREATE2.
   * @param owner The owner address for the ODProxy.
   */
  function createProxy(address owner) external returns (address) {
    return _createProxy(owner);
  }

  /**
   * @notice Creates multiple ODProxy instances using CREATE2 in a single transaction
   * @dev Function doesn't check for duplicate owners
   * @dev If an owner is address(0), it will be skipped
   * @param owners Array of addresses that will own the respective proxies
   * @return proxies Array of addresses of the deployed proxies
   */
  function createProxies(address[] memory owners) external returns (address[] memory proxies) {
    uint256 len = owners.length;
    if (len == 0) revert zeroLength();
    proxies = new address[](len);
    uint256 i;
    for (i; i < len; i++) {
      address owner = owners[i];
      if (owner != address(0)) {
        proxies[i] = _createProxy(owner);
      }
    }
  }

  /**
   * @notice Computes the address for a potential ODProxy deployment
   * @param owner The owner address for the ODProxy
   * @return predictedAddress The predicted address of the ODProxy instance
   */
  function computeProxyAddress(address owner) external view returns (address predictedAddress) {
    bytes32 salt = keccak256(abi.encodePacked(owner));
    bytes memory bytecode = type(ODProxy).creationCode;

    bytecode = abi.encodePacked(bytecode, abi.encode(owner));

    predictedAddress =
      address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))))));
  }

  // helper function to deploy a single proxy using create2
  function _createProxy(address _owner) private returns (address) {
    bytes32 salt = keccak256(abi.encodePacked(_owner));
    ODProxy proxy = new ODProxy{salt: salt}(_owner);
    emit ProxyCreated(_owner, address(proxy));
    return address(proxy);
  }
}
