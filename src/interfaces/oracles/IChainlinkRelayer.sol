// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

interface IChainlinkRelayer is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if the provided price feed address is null
  error ChainlinkRelayer_NullPriceFeed();
  /// @notice Throws if the provided sequencer uptime feed address is null
  error ChainlinkRelayer_NullSequencerUptimeFeed();
  /// @notice Throws if the provided stale threshold is null
  error ChainlinkRelayer_NullStaleThreshold();

  // --- Registry ---

  /// @notice Address of the Chainlink price feed used to consult the price
  function priceFeed() external view returns (IChainlinkOracle _priceFeed);

  /// @notice Address of the Chainlink sequencer uptime feed used to consult the sequencer status
  function sequencerUptimeFeed() external view returns (IChainlinkOracle _sequencerUptimeFeed);

  // --- Data ---

  /// @notice The multiplier used to convert the quote into an 18 decimals format
  function multiplier() external view returns (uint256 _multiplier);

  /// @notice The time threshold after which a Chainlink response is considered stale
  function staleThreshold() external view returns (uint256 _staleThreshold);
}
