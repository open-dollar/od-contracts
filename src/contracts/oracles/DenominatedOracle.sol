// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDenominatedOracle} from '@interfaces/oracles/IDenominatedOracle.sol';

import {Math, WAD} from '@libraries/Math.sol';

/**
 * @title DenominatedOracle
 * @notice Transforms a price feed between two tokens into a price feed denominated by a third token
 * @dev    Requires an external base price feed with a shared token between the price source and the denomination price source
 */
contract DenominatedOracle is IBaseOracle, IDenominatedOracle {
  using Math for uint256;

  // --- Registry ---
  /// @inheritdoc IDenominatedOracle
  IBaseOracle public priceSource;
  /// @inheritdoc IDenominatedOracle
  IBaseOracle public denominationPriceSource;

  // --- Data ---
  /**
   * @notice Concatenated symbols of the two price sources used for quoting
   *         (e.g. '(WBTC / ETH) * (ETH / USD)')
   * @dev    The order of the symbols must follow a continuous chain of tokens
   * @inheritdoc IBaseOracle
   */
  string public symbol;

  /// @inheritdoc IDenominatedOracle
  bool public inverted;

  constructor(IBaseOracle _priceSource, IBaseOracle _denominationPriceSource, bool _inverted) {
    require(address(_priceSource) != address(0), 'DelayedOracle/null-price-source');
    require(address(_denominationPriceSource) != address(0), 'DelayedOracle/null-price-source');

    priceSource = _priceSource;
    denominationPriceSource = _denominationPriceSource;
    inverted = _inverted;

    if (_inverted) {
      symbol = string(abi.encodePacked('(', priceSource.symbol(), ')^-1 / (', denominationPriceSource.symbol(), ')'));
    } else {
      symbol = string(abi.encodePacked('(', priceSource.symbol(), ') * (', denominationPriceSource.symbol(), ')'));
    }
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    (uint256 _priceSourceValue, bool _priceSourceValidity) = priceSource.getResultWithValidity();
    (uint256 _denominationPriceSourceValue, bool _denominationPriceSourceValidity) =
      denominationPriceSource.getResultWithValidity();

    _priceSourceValue = inverted ? WAD.wdiv(_priceSourceValue) : _priceSourceValue;

    _result = _priceSourceValue.wmul(_denominationPriceSourceValue);
    _validity = _priceSourceValidity && _denominationPriceSourceValidity;
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _result) {
    uint256 _priceSourceValue = priceSource.read();
    uint256 _denominationPriceSourceValue = denominationPriceSource.read();

    _priceSourceValue = inverted ? WAD.wdiv(_priceSourceValue) : _priceSourceValue;

    return _priceSourceValue.wmul(_denominationPriceSourceValue);
  }
}
