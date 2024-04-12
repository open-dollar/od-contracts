// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IChainlinkRelayerFactory} from '@interfaces/factories/IChainlinkRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {ChainlinkRelayerChild} from '@contracts/factories/ChainlinkRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

/**
 * @title  ChainlinkRelayerFactory
 * @notice This contract is used to deploy ChainlinkRelayer contracts
 * @dev    The deployed contracts are ChainlinkRelayerChild instances
 */
contract ChainlinkRelayerFactory is Authorizable, IChainlinkRelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice The enumerable set of deployed ChainlinkRelayer contracts
  EnumerableSet.AddressSet internal _chainlinkRelayers;

  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IChainlinkRelayerFactory
  function deployChainlinkRelayer(
    address _aggregator,
    uint256 _staleThreshold
  ) external isAuthorized returns (IBaseOracle _chainlinkRelayer) {
    _chainlinkRelayer = new ChainlinkRelayerChild(_aggregator, _staleThreshold);
    _chainlinkRelayers.add(address(_chainlinkRelayer));
    emit NewChainlinkRelayer(address(_chainlinkRelayer), _aggregator, _staleThreshold);
  }

  // --- Views ---

  /// @inheritdoc IChainlinkRelayerFactory
  function chainlinkRelayersList() external view returns (address[] memory _chainlinkRelayersList) {
    return _chainlinkRelayers.values();
  }
}
