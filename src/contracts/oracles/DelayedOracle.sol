// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

/**
 * @title  DelayedOracle
 * @notice Transforms a price feed into a delayed price feed with a step function
 * @dev    Requires an external mechanism to call updateResult every `updateDelay` seconds
 */
contract DelayedOracle is IBaseOracle, IDelayedOracle {
  // --- Registry ---

  /// @inheritdoc IDelayedOracle
  IBaseOracle public priceSource;

  // --- Data ---
  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @inheritdoc IDelayedOracle
  uint256 public updateDelay;
  /// @inheritdoc IDelayedOracle
  uint256 public lastUpdateTime;

  /// @notice The current valid price feed storage struct
  Feed internal _currentFeed;
  /// @notice The next valid price feed storage struct
  Feed internal _nextFeed;

  // --- Init ---

  /**
   * @param  _priceSource The address of the non-delayed price source
   * @param  _updateDelay The delay in seconds that should elapse between updates
   */
  constructor(IBaseOracle _priceSource, uint256 _updateDelay) {
    if (address(_priceSource) == address(0)) revert DelayedOracle_NullPriceSource();
    if (_updateDelay == 0) revert DelayedOracle_NullDelay();

    priceSource = _priceSource;
    updateDelay = _updateDelay;

    (uint256 _priceFeedValue, bool _hasValidValue) = _getPriceSourceResult();
    if (_hasValidValue) {
      _nextFeed = Feed(_priceFeedValue, _hasValidValue);
      _currentFeed = _nextFeed;
      lastUpdateTime = block.timestamp;

      emit UpdateResult(_currentFeed.value, lastUpdateTime);
    }

    symbol = priceSource.symbol();
  }

  /// @inheritdoc IDelayedOracle
  function updateResult() external returns (bool _success) {
    // Read the price from the median
    (uint256 _priceFeedValue, bool _hasValidValue) = _getPriceSourceResult();

    // Check if the delay to set the new feed passed
    if (!_delayHasElapsed()) {
      // If it hasn't passed, check if the upcoming feed is valid
      // in the case that it is not valid we check if we can fetch a new valid feed to replace it.
      if (!_nextFeed.isValid) {
        // Check if the newly fetched feed is valid
        if (_hasValidValue) {
          // Store the new next Feed
          _nextFeed = Feed(_priceFeedValue, _hasValidValue);
          lastUpdateTime = block.timestamp;
        }

        return _hasValidValue;
      }

      revert DelayedOracle_DelayHasNotElapsed();
    }

    // Update state
    _currentFeed = _nextFeed;
    _nextFeed = Feed(_priceFeedValue, _hasValidValue);
    lastUpdateTime = block.timestamp;

    // Emit event
    emit UpdateResult(_currentFeed.value, lastUpdateTime);

    return _hasValidValue;
  }

  // --- Getters ---

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    return (_currentFeed.value, _currentFeed.isValid);
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    if (!_currentFeed.isValid) revert DelayedOracle_NoCurrentValue();
    return _currentFeed.value;
  }

  /// @inheritdoc IDelayedOracle
  function shouldUpdate() external view returns (bool _ok) {
    return _delayHasElapsed() || !_nextFeed.isValid;
  }

  /// @inheritdoc IDelayedOracle
  function getNextResultWithValidity() external view returns (uint256 _result, bool _validity) {
    return (_nextFeed.value, _nextFeed.isValid);
  }

  /// @notice Internal view function that queries the standard price source
  function _getPriceSourceResult() internal view returns (uint256 _priceFeedValue, bool _hasValidValue) {
    return priceSource.getResultWithValidity();
  }

  /// @notice Internal view function that returns whether the delay between calls has been passed
  function _delayHasElapsed() internal view returns (bool _ok) {
    return block.timestamp >= lastUpdateTime + updateDelay;
  }
}
