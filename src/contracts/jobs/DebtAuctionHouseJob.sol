// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  LiquidationJob
 * @notice This contract contains rewarded methods to handle the the restarting of debt auctions.
 */
contract DebtAuctionHouseJob is Authorizable, Modifiable, Job {
    using Encoding for bytes;
    using Assertions for address;

    address public debtAuctionHouse;
  /**
   * @param  _debtAuctionHouse Address of the debtAuctionHouse contract
   * @param  _stabilityFeeTreasury Address of the StabilityFeeTreasury contract
   * @param  _rewardAmount Amount of tokens to reward per job transaction [wad]
   */
  constructor(
    address _debtAuctionHouse,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) validParams {
    debtAuctionHouse = _debtAuctionHouse;
  }

    /// @inheritdoc Modifiable
    function _validateParameters() internal view override(Job, Modifiable) {
        Job._validateParameters();
      }
}