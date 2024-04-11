// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

interface ISurplusBidActions is ICommonActions {
  // --- Methods ---

  /**
   * @notice Place a bid offering to provide a higher amount of coins for receiving the auctioned protocol tokens
   * @param  _surplusAuctionHouse Address of the SurplusAuctionHouse contract
   * @param  _auctionId Id of the auction to bid on
   * @param  _bidAmount Amount of system coins to bid [wad]
   */
  function increaseBidSize(address _surplusAuctionHouse, uint256 _auctionId, uint256 _bidAmount) external;

  /**
   * @notice Settles an auction, collecting the system coins if the user is the highest bidder
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _surplusAuctionHouse Address of the SurplusAuctionHouse contract
   * @param  _auctionId Id of the auction to settle
   * @dev    This method will fail if the auction is not finished
   */
  function settleAuction(address _coinJoin, address _surplusAuctionHouse, uint256 _auctionId) external;
}
