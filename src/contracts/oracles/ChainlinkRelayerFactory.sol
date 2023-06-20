// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IChainlinkRelayerFactory} from '@interfaces/oracles/IChainlinkRelayerFactory.sol';

import {ChainlinkRelayer} from '@contracts/oracles/ChainlinkRelayer.sol';

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
  ) external isAuthorized returns (address _chainlinkRelayer) {
    _chainlinkRelayer = address(new ChainlinkRelayer(_aggregator, _staleThreshold));
    _chainlinkRelayers.add(_chainlinkRelayer);
    emit NewChainlinkRelayer(_chainlinkRelayer, _aggregator, _staleThreshold);
  }

  // --- Views ---
  function chainlinkRelayersList() external view returns (address[] memory _chainlinkRelayersList) {
    return _chainlinkRelayers.values();
  }
}
