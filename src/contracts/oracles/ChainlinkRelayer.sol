// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IChainlinkRelayer} from '@interfaces/oracles/IChainlinkRelayer.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

/**
 * @title  ChainlinkRelayer
 * @notice This contracts transforms a Chainlink price feed into a standard IBaseOracle feed
 *         It also verifies that the reading is new enough, compared to a staleThreshold
 */
contract ChainlinkRelayer is IBaseOracle, IChainlinkRelayer {
  // --- Registry ---

  /// @inheritdoc IChainlinkRelayer
  IChainlinkOracle public chainlinkFeed;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @inheritdoc IChainlinkRelayer
  uint256 public multiplier;
  /// @inheritdoc IChainlinkRelayer
  uint256 public staleThreshold;

  // --- Init ---

  /**
   * @param  _aggregator The address of the Chainlink aggregator
   * @param  _staleThreshold The threshold after which the price is considered stale
   */
  constructor(address _aggregator, uint256 _staleThreshold) {
    if (_aggregator == address(0)) revert ChainlinkRelayer_NullAggregator();
    if (_staleThreshold == 0) revert ChainlinkRelayer_NullStaleThreshold();

    staleThreshold = _staleThreshold;
    chainlinkFeed = IChainlinkOracle(_aggregator);

    multiplier = 18 - chainlinkFeed.decimals();
    symbol = chainlinkFeed.description();
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    // Fetch values from Chainlink
    (, int256 _aggregatorResult,, uint256 _aggregatorTimestamp,) = chainlinkFeed.latestRoundData();

    // Parse the quote into 18 decimals format
    _result = _parseResult(_aggregatorResult);

    // Check if the price is valid
    _validity = _aggregatorResult > 0 && _isValidFeed(_aggregatorTimestamp);
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    // Fetch values from Chainlink
    (, int256 _aggregatorResult,, uint256 _aggregatorTimestamp,) = chainlinkFeed.latestRoundData();

    // Revert if price is invalid
    if (_aggregatorResult <= 0 || !_isValidFeed(_aggregatorTimestamp)) revert InvalidPriceFeed();

    // Parse the quote into 18 decimals format
    _result = _parseResult(_aggregatorResult);
  }

  /// @notice Parses the result from the aggregator into 18 decimals format
  function _parseResult(int256 _chainlinkResult) internal view returns (uint256 _result) {
    return uint256(_chainlinkResult) * 10 ** multiplier;
  }

  /// @notice Checks if the feed is valid, considering the staleThreshold and the feed timestamp
  function _isValidFeed(uint256 _feedTimestamp) internal view returns (bool _valid) {
    uint256 _now = block.timestamp;
    if (_feedTimestamp > _now) return false;
    return _now - _feedTimestamp <= staleThreshold;
  }
}
