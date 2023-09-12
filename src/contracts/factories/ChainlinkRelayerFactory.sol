// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IChainlinkRelayerFactory} from '@interfaces/factories/IChainlinkRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {ChainlinkRelayerChild} from '@contracts/factories/ChainlinkRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract ChainlinkRelayerFactory is Authorizable, IChainlinkRelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---
  EnumerableSet.AddressSet internal _chainlinkRelayers;

  // --- Init ---
  constructor() Authorizable(msg.sender) {}

  // --- Methods ---
  function deployChainlinkRelayer(
    address _aggregator,
    uint256 _staleThreshold
  ) external isAuthorized returns (IBaseOracle _chainlinkRelayer) {
    _chainlinkRelayer = new ChainlinkRelayerChild(_aggregator, _staleThreshold);
    _chainlinkRelayers.add(address(_chainlinkRelayer));
    emit NewChainlinkRelayer(address(_chainlinkRelayer), _aggregator, _staleThreshold);
  }

  // --- Views ---
  function chainlinkRelayersList() external view returns (address[] memory _chainlinkRelayersList) {
    return _chainlinkRelayers.values();
  }
}
