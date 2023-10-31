// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

interface IUniV3Relayer is IBaseOracle {
  // --- Errors ---

  /// @notice Throws if the provided pool (baseToken, quoteToken, feeTier) is non-existent
  error UniV3Relayer_InvalidPool();

  // --- Registry ---

  /// @notice Address of the UniswapV3Pool used to consult the TWAP
  function uniV3Pool() external view returns (address _uniV3Pool);

  /// @notice Address of the base token used to consult the quote from
  function baseToken() external view returns (address _baseToken);

  /// @notice Address of the token used as a quote reference
  function quoteToken() external view returns (address _quoteToken);

  // --- Data ---

  /// @notice The amount in wei of the base token used to consult the pool for a quote
  function baseAmount() external view returns (uint128 _baseAmount);

  /// @notice The multiplier used to convert the quote into an 18 decimals format
  function multiplier() external view returns (uint256 _multiplier);

  /// @notice The length of the TWAP used to consult the pool
  function quotePeriod() external view returns (uint32 _quotePeriod);
}
