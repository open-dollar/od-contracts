// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IChainlinkRelayerChild} from '@interfaces/factories/IChainlinkRelayerChild.sol';

import {ChainlinkRelayer} from '@contracts/oracles/ChainlinkRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  ChainlinkRelayerChild
 * @notice This contract inherits all the functionality of ChainlinkRelayer to be factory deployed
 */
contract ChainlinkRelayerChild is ChainlinkRelayer, FactoryChild, IChainlinkRelayerChild {
  // --- Init ---

  /**
   * @param  _aggregator The address of the aggregator to relay
   * @param  _staleThreshold The threshold in seconds to consider the aggregator stale
   */
  constructor(address _aggregator, uint256 _staleThreshold) ChainlinkRelayer(_aggregator, _staleThreshold) {}
}
