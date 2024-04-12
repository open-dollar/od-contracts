// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

interface IDebtBidActions is ICommonActions {
  // --- Methods ---

  /**
   * @notice Place a bid offering to receive a lesser amount of protocol tokens for covering the auctioned debt amount
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _debtAuctionHouse Address of the DebtAuctionHouse contract
   * @param  _auctionId Id of the auction to bid on
   * @param  _soldAmount Amount of protocol tokens to receive [wad]
   */
  function decreaseSoldAmount(
    address _coinJoin,
    address _debtAuctionHouse,
    uint256 _auctionId,
    uint256 _soldAmount
  ) external;

  /**
   * @notice Settles an auction, collecting the protocol tokens if the user is the highest bidder
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _debtAuctionHouse Address of the DebtAuctionHouse contract
   * @param  _auctionId Id of the auction to settle
   * @dev    This method will fail if the auction is not finished
   */
  function settleAuction(address _coinJoin, address _debtAuctionHouse, uint256 _auctionId) external;

  /**
   * @notice Collects the protocol tokens that the proxy has
   * @param  _protocolToken Address of the protocol token
   * @dev    This method is used to collect protocol tokens from an auction that was settled by another user
   */
  function collectProtocolTokens(address _protocolToken) external;
}
