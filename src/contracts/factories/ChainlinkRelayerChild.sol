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
   * @param  _priceFeed The address of the price feed to relay
   * @param  _sequencerUptimeFeed The address of the sequencer uptime feed to relay
   * @param  _staleThreshold The threshold in seconds to consider the aggregator stale
   */
  constructor(
    address _priceFeed,
    address _sequencerUptimeFeed,
    uint256 _staleThreshold
  ) ChainlinkRelayer(_priceFeed, _sequencerUptimeFeed, _staleThreshold) {}
}
