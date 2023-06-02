// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ISettlementSurplusAuctioneer is IAuthorizable, IModifiable {
  // --- Events ---
  event AuctionSurplus(uint256 indexed _id, uint256 _lastSurplusAuctionTime, uint256 _coinBalance);

  // --- Errors ---
  error SSA_AccountingEngineStillEnabled();
  error SSA_SurplusAuctionDelayNotPassed();

  // --- Data ---
  function lastSurplusTime() external view returns (uint256 _lastSurplusTime);

  // --- Registry ---
  function accountingEngine() external view returns (IAccountingEngine _accountingEngine);
  function surplusAuctionHouse() external view returns (ISurplusAuctionHouse _surplusAuctionHouse);
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  // --- Core Logic ---
  function auctionSurplus() external returns (uint256 _id);
}
