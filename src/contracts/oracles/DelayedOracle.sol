// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

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

  Feed internal _currentFeed;
  Feed internal _nextFeed;

  constructor(IBaseOracle _priceSource, uint256 _updateDelay) {
    require(address(_priceSource) != address(0), 'DelayedOracle/null-price-source');
    require(_updateDelay != 0, 'DelayedOracle/null-delay');

    priceSource = _priceSource;
    updateDelay = _updateDelay;

    (uint256 _priceFeedValue, bool _hasValidValue) = _getPriceSourceResult();
    if (_hasValidValue) {
      _nextFeed = Feed(_priceFeedValue, true);
      _currentFeed = _nextFeed;
      lastUpdateTime = block.timestamp;

      emit UpdateResult(_currentFeed.value, lastUpdateTime);
    }

    symbol = priceSource.symbol();
  }

  /// @inheritdoc IDelayedOracle
  function updateResult() external returns (bool _success) {
    // Check if the delay passed
    if (!_delayHasElapsed()) revert DelayHasNotElapsed();
    // Read the price from the median
    (uint256 _priceFeedValue, bool _hasValidValue) = _getPriceSourceResult();
    // If the value is valid, update storage
    if (_hasValidValue) {
      // Update state
      _currentFeed = _nextFeed;
      _nextFeed = Feed(_priceFeedValue, true);
      lastUpdateTime = block.timestamp;
      // Emit event
      emit UpdateResult(uint256(_currentFeed.value), lastUpdateTime);
    }
    return _hasValidValue;
  }

  // --- Getters ---

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    return (_currentFeed.value, _currentFeed.isValid);
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    require(_currentFeed.isValid, 'OSM/no-current-value');
    return _currentFeed.value;
  }

  /// @inheritdoc IDelayedOracle
  function shouldUpdate() external view returns (bool _ok) {
    return _delayHasElapsed();
  }

  /// @inheritdoc IDelayedOracle
  function getNextResultWithValidity() external view returns (uint256 _result, bool _validity) {
    return (_nextFeed.value, _nextFeed.isValid);
  }

  /**
   * @dev View function that queries the standard price source
   */
  function _getPriceSourceResult() internal view returns (uint256 _priceFeedValue, bool _hasValidValue) {
    return IBaseOracle(priceSource).getResultWithValidity();
  }

  /**
   * @dev View function that returns whether the delay between calls has been passed
   */
  function _delayHasElapsed() internal view returns (bool _ok) {
    return block.timestamp >= lastUpdateTime + updateDelay;
  }
}
