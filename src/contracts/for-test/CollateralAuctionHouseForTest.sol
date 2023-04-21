// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

contract CollateralAuctionHouseForTest {
  uint256 auctionId = 123_456;

  function startAuction(
    address _forgoneCollateralReceiver,
    address _initialBidder,
    uint256 _amountToRaise,
    uint256 _collateralToSell,
    uint256 _initialBid
  ) external returns (uint256 _id) {
    return auctionId;
  }
}
