// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ISettlementSurplusAuctioneer is IAuthorizable, IModifiable {
  // --- Events ---

  /**
   * @notice Emitted when the contract triggers a surplus auction
   * @param  _id The id of the started auction
   * @param  _lastSurplusAuctionTime The timestamp of the surplus auction
   * @param  _coinBalance The remaining coin balance of the contract
   */
  event AuctionSurplus(uint256 indexed _id, uint256 _lastSurplusAuctionTime, uint256 _coinBalance);

  // --- Errors ---

  /// @notice Throws if the AccountingEngine is still enabled
  error SSA_AccountingEngineStillEnabled();
  /// @notice Throws if the surplus auction delay has not passed
  error SSA_SurplusAuctionDelayNotPassed();

  // --- Data ---

  /// @notice The last time when this contract triggered a surplus auction
  function lastSurplusTime() external view returns (uint256 _lastSurplusTime);

  // --- Registry ---

  /// @notice The address of the AccountingEngine
  function accountingEngine() external view returns (IAccountingEngine _accountingEngine);
  /// @notice The address of the SurplusAuctionHouse
  function surplusAuctionHouse() external view returns (ISurplusAuctionHouse _surplusAuctionHouse);
  /// @notice The address of the SAFEEngine
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  // --- Core Logic ---

  /**
   * @notice Starts a new surplus auction
   * @return _id The id of the started auction
   * @dev The contract reads surplus auction parameters from the AccountingEngine
   */
  function auctionSurplus() external returns (uint256 _id);
}
