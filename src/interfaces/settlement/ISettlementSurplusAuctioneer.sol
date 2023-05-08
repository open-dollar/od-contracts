// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingEngine as AccountingEngineLike} from '@interfaces/IAccountingEngine.sol';
import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse as SurplusAuctionHouseLike} from '@interfaces/ISurplusAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface ISettlementSurplusAuctioneer is IAuthorizable, IModifiable {
  // --- Events ---
  event AuctionSurplus(uint256 indexed _id, uint256 _lastSurplusAuctionTime, uint256 _coinBalance);

  // --- Data ---
  function accountingEngine() external view returns (AccountingEngineLike _accountingEngine);
  function surplusAuctionHouse() external view returns (SurplusAuctionHouseLike _surplusAuctionHouse);
  function safeEngine() external view returns (SAFEEngineLike _safeEngine);
  function lastSurplusTime() external view returns (uint256 _lastSurplusTime);

  // --- Core Logic ---
  function auctionSurplus() external returns (uint256 _id);
}
