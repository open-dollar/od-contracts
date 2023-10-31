// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

interface IDenominatedOracle is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if either the provided price source or denominated price source are null
  error DenominatedOracle_NullPriceSource();

  /**
   * @notice Address of the base price source that is used to calculate the price
   * @dev    Assumes that the price source is a valid IBaseOracle
   */
  function priceSource() external view returns (IBaseOracle _priceSource);

  /**
   * @notice Address of the base price source that is used to calculate the denominated price
   * @dev    Assumes that the price source is a valid IBaseOracle
   */
  function denominationPriceSource() external view returns (IBaseOracle _denominationPriceSource);

  /**
   * @notice Whether the price source quote should be inverted or not
   * @dev    Used to fix an inverted path of token quotes into a continuous chain of tokens (e.g. '(ETH / WBTC)^-1 * (ETH / USD)')
   */
  function inverted() external view returns (bool _inverted);
}
