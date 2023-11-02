// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IChainlinkRelayer} from '@interfaces/oracles/IChainlinkRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

/**
 * @title  ChainlinkRelayer
 * @notice This contracts transforms a Chainlink price feed into a standard IBaseOracle feed
 *         It also verifies that the reading is new enough, compared to a staleThreshold
 */
contract ChainlinkRelayer is IBaseOracle, IChainlinkRelayer {
  // --- Registry ---

  /// @inheritdoc IChainlinkRelayer
  IChainlinkOracle public priceFeed;
  /// @inheritdoc IChainlinkRelayer
  IChainlinkOracle public sequencerUptimeFeed;

  // --- Data ---

  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @inheritdoc IChainlinkRelayer
  uint256 public multiplier;
  /// @inheritdoc IChainlinkRelayer
  uint256 public staleThreshold;

  // --- Init ---

  /**
   * @param  _priceFeed The address of the Chainlink price feed
   * @param  _sequencerUptimeFeed The address of the Chainlink sequencer uptime feed
   * @param  _staleThreshold The threshold after which the price is considered stale
   */
  constructor(address _priceFeed, address _sequencerUptimeFeed, uint256 _staleThreshold) {
    if (_priceFeed == address(0)) revert ChainlinkRelayer_NullPriceFeed();
    if (_sequencerUptimeFeed == address(0)) revert ChainlinkRelayer_NullSequencerUptimeFeed();
    if (_staleThreshold == 0) revert ChainlinkRelayer_NullStaleThreshold();

    priceFeed = IChainlinkOracle(_priceFeed);
    sequencerUptimeFeed = IChainlinkOracle(_sequencerUptimeFeed);
    staleThreshold = _staleThreshold;

    multiplier = 18 - priceFeed.decimals();
    symbol = priceFeed.description();
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    // Fetch values from Chainlink
    (, int256 _feedResult,, uint256 _feedTimestamp,) = priceFeed.latestRoundData();

    // Parse the quote into 18 decimals format
    _result = _parseResult(_feedResult);

    // Check if the price is valid
    _validity = _feedResult > 0 && _isValidFeed(_feedTimestamp);
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    // Fetch values from Chainlink
    (, int256 _feedResult,, uint256 _feedTimestamp,) = priceFeed.latestRoundData();

    // Revert if price is invalid
    if (_feedResult <= 0 || !_isValidFeed(_feedTimestamp)) revert InvalidPriceFeed();

    // Parse the quote into 18 decimals format
    _result = _parseResult(_feedResult);
  }

  /// @notice Parses the result from the price feed into 18 decimals format
  function _parseResult(int256 _feedResult) internal view returns (uint256 _result) {
    return uint256(_feedResult) * 10 ** multiplier;
  }

  /// @notice Checks if the feed is valid, considering the sequencer status, the staleThreshold and the feed timestamp
  function _isValidFeed(uint256 _feedTimestamp) internal view returns (bool _valid) {
    // Check the sequencer status
    (, int256 _feedStatus,,,) = sequencerUptimeFeed.latestRoundData();

    // Status == 0: Sequencer is up
    // Status == 1: Sequencer is down
    bool _isSequencerUp = _feedStatus == 0;
    if (!_isSequencerUp) return false;

    // Make sure the staleThreshold has not passed after the feed timestamp
    uint256 _timeSinceFeed = block.timestamp - _feedTimestamp;
    return _timeSinceFeed <= staleThreshold;
  }
}
