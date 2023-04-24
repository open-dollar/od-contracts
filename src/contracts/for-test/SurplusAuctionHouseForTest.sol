// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {SurplusAuctionHouse, ISurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';

contract SurplusAuctionHouseForTest is SurplusAuctionHouse {
  constructor(
    address _safeEngine,
    address _protocolToken,
    uint256 _recyclingPercentage
  ) SurplusAuctionHouse(_safeEngine, _protocolToken, _recyclingPercentage) {}

  function addBid(
    uint256 _id,
    uint256 _bidAmount,
    uint256 _amountToSell,
    address _highBidder,
    uint48 _bidExpiry,
    uint48 _auctionDeadline
  ) external {
    bids[_id].bidAmount = _bidAmount;
    bids[_id].amountToSell = _amountToSell;
    bids[_id].highBidder = _highBidder;
    bids[_id].bidExpiry = _bidExpiry;
    bids[_id].auctionDeadline = _auctionDeadline;
  }
}
