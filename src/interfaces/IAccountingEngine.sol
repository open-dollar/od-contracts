// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {IProtocolTokenAuthority} from '@interfaces/external/IProtocolTokenAuthority.sol';
import {ISystemStakingPool} from '@interfaces/external/ISystemStakingPool.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface IAccountingEngine is IAuthorizable, IDisableable {
  function pushDebtToQueue(uint256 _debtBlock) external;
  function popDebtFromQueue(uint256 _debtBlockTimestamp) external;
  function surplusAuctionDelay() external view returns (uint256 _surplusAuctionDelay);
  function surplusAuctionAmountToSell() external view returns (uint256 _surplusAmountToSell);
  function surplusAuctionHouse() external view returns (ISurplusAuctionHouse _surplusAuctionHouse);
  function debtAuctionHouse() external view returns (IDebtAuctionHouse _debtAuctionHouse);
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function totalOnAuctionDebt() external view returns (uint256 _totalOnAuctionDebt);
  function cancelAuctionedDebtWithSurplus(uint256 _rad) external;
  function auctionDebt() external returns (uint256 _id);
  function auctionSurplus() external returns (uint256 _id);
  function transferExtraSurplus() external;
  function transferPostSettlementSurplus() external;
  function totalQueuedDebt() external view returns (uint256 _totalQueuedDebt);
  function debtQueue(uint256 _blockTimestamp) external view returns (uint256 _debtQueue);
  function debtPoppers(uint256 _blockTimestamp) external view returns (address _debtPopperAddress);
  function popDebtDelay() external view returns (uint256 _popDebtDelay);
  function settleDebt(uint256 rad) external;
  function debtAuctionBidSize() external view returns (uint256 _debtAuctionBidSize);
  function initialDebtAuctionMintedTokens() external view returns (uint256 _initialDebtAuctionMintedTokens);
  function lastSurplusAuctionTime() external view returns (uint256 _lastSurplusAuctionTime);
  function lastSurplusTransferTime() external view returns (uint256 _lastSurplusTransferTime);
  function surplusBuffer() external view returns (uint256 _surplusBuffer);
  function unqueuedUnauctionedDebt() external view returns (uint256 _unqueuedUnauctionedDebt);
  function protocolTokenAuthority() external view returns (IProtocolTokenAuthority _protocolTokenAuthority);
  function extraSurplusIsTransferred() external view returns (uint256 _extraSurplusIsTransferred);
  function surplusTransferAmount() external view returns (uint256 _surplusTransferAmount);
  function systemStakingPool() external view returns (ISystemStakingPool _systemStakingPool);
  function extraSurplusReceiver() external view returns (address _extraSurplusReceiver);
  function surplusTransferDelay() external view returns (uint256 _surplusTransferDelay);
}
