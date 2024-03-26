// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/**
 * @title  DebtAuctionHouseJob
 * @notice This contract contains the interface for DebtAuctionHouseJob.
 */
interface IDebtAuctionHouseJob {
  /**
   * @notice Restarts an auction with a reward
   * @param auctionId the Id of the auction to be restarted
  */
  function restartAuction(uint256 auctionId) external;

  /**
   * @notice Restarts an auction without a reward
   * @param auctionId the Id of the auction to be restarted
  */
  function restartAuctionWithoutReward(uint256 auctionId) external;

}
