// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IAccountingEngine is IAuthorizable, IDisableable, IModifiable {
  // --- Events ---
  event PushDebtToQueue(uint256 indexed _timestamp, uint256 _debtQueueBlock, uint256 _totalQueuedDebt);
  event PopDebtFromQueue(uint256 indexed _timestamp, uint256 _debtQueueBlock, uint256 _totalQueuedDebt);
  event SettleDebt(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance);
  event CancelAuctionedDebtWithSurplus(
    uint256 _rad, uint256 _totalOnAuctionDebt, uint256 _coinBalance, uint256 _debtBalance
  );
  event AuctionDebt(uint256 indexed _id, uint256 _totalOnAuctionDebt, uint256 _debtBalance);
  event AuctionSurplus(uint256 indexed _id, uint256 _lastSurplusTime, uint256 _coinBalance);
  event TransferPostSettlementSurplus(address _postSettlementSurplusDrain, uint256 _coinBalance, uint256 _debtBalance);
  event TransferExtraSurplus(address indexed _extraSurplusReceiver, uint256 _lastSurplusTime, uint256 _coinBalance);

  // --- Errors ---
  error AccEng_DebtAuctionDisabled();
  error AccEng_SurplusAuctionDisabled();
  error AccEng_SurplusTransferDisabled();
  error AccEng_InsufficientDebt();
  error AccEng_InsufficientSurplus();
  error AccEng_SurplusNotZero();
  error AccEng_DebtNotZero();
  error AccEng_NullAmount();
  error AccEng_NullSurplusReceiver();
  error AccEng_SurplusCooldown();
  error AccEng_PopDebtCooldown();
  error AccEng_PostSettlementCooldown();

  // --- Structs ---
  struct AccountingEngineParams {
    // Whether the system transfers surplus instead of auctioning it
    uint256 surplusIsTransferred;
    // Delay between surplus actions
    uint256 surplusDelay;
    // Delay after which debt can be popped from debtQueue
    uint256 popDebtDelay;
    // Time to wait (post settlement) until any remaining surplus can be transferred to the settlement auctioneer
    uint256 disableCooldown;
    // Amount of surplus stability fees transferred or sold in one surplus auction
    uint256 surplusAmount;
    // Amount of stability fees that need to accrue in this contract before any surplus auction can start
    uint256 surplusBuffer;
    // Amount of protocol tokens to be minted post-auction
    uint256 debtAuctionMintedTokens;
    // Amount of debt sold in one debt auction (initial coin bid for debtAuctionMintedTokens protocol tokens)
    uint256 debtAuctionBidSize;
  }

  // --- Params ---
  function params() external view returns (AccountingEngineParams memory _params);

  // --- Registry ---
  // SAFE database
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  // Contract that handles auctions for surplus stability fees (sell coins for protocol tokens that are then burned)
  function surplusAuctionHouse() external view returns (ISurplusAuctionHouse _surplusAuctionHouse);
  //Contract that handles auctions for debt that couldn't be covered by collateral auctions
  function debtAuctionHouse() external view returns (IDebtAuctionHouse _debtAuctionHouse);
  // Contract that auctions extra surplus after settlement is triggered
  function postSettlementSurplusDrain() external view returns (address _postSettlementSurplusDrain);
  // Address that receives extra surplus transfers
  function extraSurplusReceiver() external view returns (address _extraSurplusReceiver);

  // --- Data ---
  function totalOnAuctionDebt() external view returns (uint256 _totalOnAuctionDebt);
  function totalQueuedDebt() external view returns (uint256 _totalQueuedDebt);
  function debtQueue(uint256 _blockTimestamp) external view returns (uint256 _debtQueue);
  function lastSurplusTime() external view returns (uint256 _lastSurplusTime);
  function unqueuedUnauctionedDebt() external view returns (uint256 _unqueuedUnauctionedDebt);
  function disableTimestamp() external view returns (uint256 _disableTimestamp);

  // --- Methods ---
  function auctionDebt() external returns (uint256 _id);
  function auctionSurplus() external returns (uint256 _id);
  function cancelAuctionedDebtWithSurplus(uint256 _rad) external;
  function pushDebtToQueue(uint256 _debtBlock) external;
  function popDebtFromQueue(uint256 _debtBlockTimestamp) external;
  function settleDebt(uint256 _rad) external;
  function transferExtraSurplus() external;
  function transferPostSettlementSurplus() external;
}
