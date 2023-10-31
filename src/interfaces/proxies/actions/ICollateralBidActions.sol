// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

interface ICollateralBidActions is ICommonActions {
  // --- Errors ---

  /// @notice Throws if the adjusted bid is invalid
  error ColActions_InvalidAdjustedBid();
  /// @notice Throws if the received collateral is less than the minimum
  error ColActions_InsufficientCollateralReceived(uint256 _minCollateralAmount, uint256 _received);

  // --- Methods ---

  /**
   * @notice Buys collateral tokens from a collateral auction
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _collateralAuctionHouse Address of the CollateralAuctionHouse contract
   * @param  _auctionId Id of the auction to bid on
   * @param  _minCollateralAmount Minimum amount of collateral tokens to buy [wad]
   * @param  _bidAmount Amount of system coins to bid [wad]
   * @dev    This method will fail if the purchased amount is lower than the minimum, or the bid higher than the specified amount
   */
  function buyCollateral(
    address _coinJoin,
    address _collateralJoin,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _minCollateralAmount,
    uint256 _bidAmount
  ) external;
}
