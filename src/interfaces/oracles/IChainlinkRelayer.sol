// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

interface IChainlinkRelayer is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if the provided aggregator address is null
  error ChainlinkRelayer_NullAggregator();
  /// @notice Throws if the provided stale threshold is null
  error ChainlinkRelayer_NullStaleThreshold();

  // --- Registry ---

  /// @notice Address of the Chainlink aggregator used to consult the price
  function chainlinkFeed() external view returns (IChainlinkOracle _chainlinkFeed);

  // --- Data ---

  /// @notice The multiplier used to convert the quote into an 18 decimals format
  function multiplier() external view returns (uint256 _multiplier);

  /// @notice The time threshold after which a Chainlink response is considered stale
  function staleThreshold() external view returns (uint256 _staleThreshold);
}
