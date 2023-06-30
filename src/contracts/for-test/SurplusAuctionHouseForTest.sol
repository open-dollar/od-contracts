// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SurplusAuctionHouse, ISurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';

contract SurplusAuctionHouseForTest is SurplusAuctionHouse {
  constructor(
    address _safeEngine,
    address _protocolToken,
    SurplusAuctionHouseParams memory _sahParams
  ) SurplusAuctionHouse(_safeEngine, _protocolToken, _sahParams) {}

  function addBid(
    uint256 _id,
    uint256 _bidAmount,
    uint256 _amountToSell,
    address _highBidder,
    uint256 _bidExpiry,
    uint256 _auctionDeadline
  ) external {
    bids[_id].bidAmount = _bidAmount;
    bids[_id].amountToSell = _amountToSell;
    bids[_id].highBidder = _highBidder;
    bids[_id].bidExpiry = _bidExpiry;
    bids[_id].auctionDeadline = _auctionDeadline;
  }
}
