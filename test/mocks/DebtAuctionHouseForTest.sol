// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {DebtAuctionHouse, IDebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';

contract DebtAuctionHouseForTest is DebtAuctionHouse {
  constructor(
    address _safeEngine,
    address _protocolToken,
    DebtAuctionHouseParams memory _dahParams
  ) DebtAuctionHouse(_safeEngine, _protocolToken, _dahParams) {}

  function addAuction(
    uint256 _id,
    uint256 _bidAmount,
    uint256 _amountToSell,
    address _highBidder,
    uint256 _bidExpiry,
    uint256 _auctionDeadline
  ) external {
    _auctions[_id].bidAmount = _bidAmount;
    _auctions[_id].amountToSell = _amountToSell;
    _auctions[_id].highBidder = _highBidder;
    _auctions[_id].bidExpiry = _bidExpiry;
    _auctions[_id].auctionDeadline = _auctionDeadline;
  }
}
