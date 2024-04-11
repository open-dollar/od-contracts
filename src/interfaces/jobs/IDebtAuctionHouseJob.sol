// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IJob} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
/**
 * @title  IDebtAuctionHouseJob
 * @notice This contract contains the interface for DebtAuctionHouseJob.
 */

interface IDebtAuctionHouseJob is IAuthorizable, IModifiable, IJob {
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

  /// @notice get the debt auction house
  function debtAuctionHouse() external returns (IDebtAuctionHouse _debtAuctionHouse);
}
