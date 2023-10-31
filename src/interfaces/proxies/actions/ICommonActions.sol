// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface ICommonActions {
  // --- Errors ---

  /// @notice Throws if the method is being directly called, without a delegate call
  error OnlyDelegateCalls();

  // --- Methods ---

  /**
   * @notice Joins system coins into the safeEngine
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _dst Address of the SAFE to join the coins into
   * @param  _wad Amount of coins to join [wad]
   */
  function joinSystemCoins(address _coinJoin, address _dst, uint256 _wad) external;

  /**
   * @notice Exits system coins from the safeEngine
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _coinsToExit Amount of coins to exit [wad]
   */
  function exitSystemCoins(address _coinJoin, uint256 _coinsToExit) external;

  /**
   * @notice Exits all system coins from the safeEngine
   * @param  _coinJoin Address of the CoinJoin contract
   */
  function exitAllSystemCoins(address _coinJoin) external;

  /**
   * @notice Exits collateral tokens from the safeEngine
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _wad Amount of collateral tokens to exit [wad]
   */
  function exitCollateral(address _collateralJoin, uint256 _wad) external;
}
