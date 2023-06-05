// SPDX-License-Identifier: GPL-3.0
/// AccountingEngine.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Math} from '@libraries/Math.sol';

contract AccountingEngine is Authorizable, Modifiable, Disableable, IAccountingEngine {
  using Encoding for bytes;

  // --- Auth ---
  function addAuthorization(address _account) external override(Authorizable, IAuthorizable) isAuthorized whenEnabled {
    _addAuthorization(_account);
  }

  // --- Registry ---
  ISAFEEngine public safeEngine;
  ISurplusAuctionHouse public surplusAuctionHouse;
  IDebtAuctionHouse public debtAuctionHouse;
  address public postSettlementSurplusDrain;
  address public extraSurplusReceiver;

  // --- Params ---
  AccountingEngineParams internal _params;

  function params() external view returns (AccountingEngineParams memory _accEngineParams) {
    return _params;
  }

  // --- Data ---
  // Debt blocks that need to be covered by auctions
  mapping(uint256 => uint256) public debtQueue; // [unix timestamp => rad]
  // Total debt in the queue
  uint256 public totalQueuedDebt; // [rad]
  // Total debt being auctioned in DebtAuctionHouse
  uint256 public totalOnAuctionDebt; // [rad]
  // When the last surplus transfer or auction was triggered
  uint256 public lastSurplusTime; // [unix timestamp]
  // When the contract was disabled
  uint256 public disableTimestamp; // [unix timestamp]

  // --- Init ---
  constructor(address _safeEngine, address _surplusAuctionHouse, address _debtAuctionHouse) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine);
    surplusAuctionHouse = ISurplusAuctionHouse(_surplusAuctionHouse);
    debtAuctionHouse = IDebtAuctionHouse(_debtAuctionHouse);

    safeEngine.approveSAFEModification(_surplusAuctionHouse);

    lastSurplusTime = block.timestamp;
  }

  // --- Getters ---
  /**
   * @notice Returns the amount of bad debt that is not in the debtQueue and is not currently handled by debt auctions
   */
  function unqueuedUnauctionedDebt() public view returns (uint256 __unqueuedUnauctionedDebt) {
    return _unqueuedUnauctionedDebt(safeEngine.debtBalance(address(this)));
  }

  function _unqueuedUnauctionedDebt(uint256 _debtBalance) internal view returns (uint256 __unqueuedUnauctionedDebt) {
    return (_debtBalance - totalQueuedDebt) - totalOnAuctionDebt;
  }

  // --- Debt Queueing ---
  /**
   * @notice Push a block of bad debt to the debt queue
   * @dev    Debt is locked in a queue to give the system enough time to auction collateral
   *         and gather surplus
   * @param  _debtBlock Amount of debt to push
   */
  function pushDebtToQueue(uint256 _debtBlock) external isAuthorized {
    debtQueue[block.timestamp] = debtQueue[block.timestamp] + _debtBlock;
    totalQueuedDebt = totalQueuedDebt + _debtBlock;
    emit PushDebtToQueue(block.timestamp, debtQueue[block.timestamp], totalQueuedDebt);
  }

  /**
   * @notice Pop a block of bad debt from the debt queue
   * @dev    A block of debt can be popped from the queue after popDebtDelay seconds have passed since it was
   *           added there
   * @param  _debtBlockTimestamp Timestamp of the block of debt that should be popped out
   */
  function popDebtFromQueue(uint256 _debtBlockTimestamp) external {
    if (block.timestamp < _debtBlockTimestamp + _params.popDebtDelay) revert AccEng_PopDebtCooldown();
    uint256 _debtBlock = debtQueue[_debtBlockTimestamp];
    if (_debtBlock == 0) revert AccEng_NullAmount();
    totalQueuedDebt = totalQueuedDebt - _debtBlock;
    emit PopDebtFromQueue(block.timestamp, _debtBlock, totalQueuedDebt);
    debtQueue[_debtBlockTimestamp] = 0;
  }

  // Debt settlement
  /**
   * @notice Destroy an equal amount of coins and bad debt
   * @dev We can only destroy debt that is not locked in the queue and also not in a debt auction
   * @param _rad Amount of coins/debt to destroy (number with 45 decimals)
   */
  function settleDebt(uint256 _rad) external {
    _settleDebt(_rad);
  }

  function _settleDebt(uint256 _rad) internal returns (uint256 _coinBalance, uint256 _debtBalance) {
    _coinBalance = safeEngine.coinBalance(address(this));
    _debtBalance = safeEngine.debtBalance(address(this));
    if (_rad > _coinBalance) revert AccEng_InsufficientSurplus();
    if (_rad > _unqueuedUnauctionedDebt(_debtBalance)) revert AccEng_InsufficientDebt();
    _coinBalance -= _rad;
    _debtBalance -= _rad;
    safeEngine.settleDebt(_rad);
    emit SettleDebt(_rad, _coinBalance, _debtBalance);
  }

  /**
   * @notice Use surplus coins to destroy debt that was in a debt auction
   * @param _rad Amount of coins/debt to destroy (number with 45 decimals)
   */
  function cancelAuctionedDebtWithSurplus(uint256 _rad) external {
    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    if (_rad > _coinBalance) revert AccEng_InsufficientSurplus();
    if (_rad > totalOnAuctionDebt) revert AccEng_InsufficientDebt();
    totalOnAuctionDebt -= _rad;
    safeEngine.settleDebt(_rad);
    emit CancelAuctionedDebtWithSurplus(
      _rad, totalOnAuctionDebt, _coinBalance - _rad, safeEngine.debtBalance(address(this))
    );
  }

  // Debt auction
  /**
   * @notice Start a debt auction (print protocol tokens in exchange for coins so that the
   *         system can be recapitalized)
   * @dev    We can only auction debt that is not already being auctioned and is not locked in the debt queue
   * @return _id Id of the debt auction that was started
   */
  function auctionDebt() external returns (uint256 _id) {
    if (_params.debtAuctionBidSize == 0) revert AccEng_DebtAuctionDisabled();
    if (_params.debtAuctionBidSize > unqueuedUnauctionedDebt()) revert AccEng_InsufficientDebt();
    (, uint256 _newDebtBalance) = _settleDebt(safeEngine.coinBalance(address(this)));

    totalOnAuctionDebt = totalOnAuctionDebt + _params.debtAuctionBidSize;
    _id = debtAuctionHouse.startAuction(address(this), _params.debtAuctionMintedTokens, _params.debtAuctionBidSize);
    emit AuctionDebt(_id, totalOnAuctionDebt, _newDebtBalance);
  }

  // Surplus auction
  /**
   * @notice Start a surplus auction
   * @dev    We can only auction surplus if we wait at least 'surplusDelay' seconds since the last
   *         surplus auction trigger, if we keep enough surplus in the buffer and if there is no bad debt left to settle
   * @return _id the Id of the surplus auction that was started
   */
  function auctionSurplus() external returns (uint256 _id) {
    if (_params.surplusIsTransferred == 1) revert AccEng_SurplusAuctionDisabled();
    if (_params.surplusAmount == 0) revert AccEng_NullAmount();
    if (block.timestamp < lastSurplusTime + _params.surplusDelay) revert AccEng_SurplusCooldown();
    (uint256 _newCoinBalance, uint256 _newDebtBalance) = _settleDebt(unqueuedUnauctionedDebt());
    if (_newCoinBalance < _newDebtBalance + _params.surplusAmount + _params.surplusBuffer) {
      revert AccEng_InsufficientSurplus();
    }

    lastSurplusTime = block.timestamp;
    _id = surplusAuctionHouse.startAuction(_params.surplusAmount, 0);
    emit AuctionSurplus(_id, lastSurplusTime, _newCoinBalance);
  }

  // Extra surplus transfers/surplus auction alternative
  /**
   * @notice Send surplus to an address as an alternative to surplus auctions
   * @dev    We can only transfer surplus if we wait at least 'surplusDelay' seconds since the last
   *           transfer, if we keep enough surplus in the buffer and if there is no bad debt left to settle
   */
  function transferExtraSurplus() external {
    if (_params.surplusIsTransferred != 1) revert AccEng_SurplusTransferDisabled();
    if (extraSurplusReceiver == address(0)) revert AccEng_NullSurplusReceiver();
    if (_params.surplusAmount == 0) revert AccEng_NullAmount();
    (uint256 _newCoinBalance, uint256 _newDebtBalance) = _settleDebt(unqueuedUnauctionedDebt());
    if (block.timestamp < lastSurplusTime + _params.surplusDelay) revert AccEng_SurplusCooldown();
    if (_newCoinBalance < _newDebtBalance + _params.surplusAmount + _params.surplusBuffer) {
      revert AccEng_InsufficientSurplus();
    }
    lastSurplusTime = block.timestamp;

    safeEngine.transferInternalCoins(address(this), extraSurplusReceiver, _params.surplusAmount);
    emit TransferExtraSurplus(extraSurplusReceiver, lastSurplusTime, _newCoinBalance);
  }

  // --- Shutdown ---

  /**
   * @notice Disable this contract (normally called by Global Settlement)
   * @dev When it's being disabled, the contract will record the current timestamp. Afterwards,
   *      the contract tries to settle as much debt as possible (if there's any) with any surplus that's
   *      left in the AccountingEngine
   */
  function _onContractDisable() internal override {
    totalQueuedDebt = 0;
    totalOnAuctionDebt = 0;
    disableTimestamp = block.timestamp;

    surplusAuctionHouse.disableContract();
    debtAuctionHouse.disableContract();

    uint256 _debtToSettle = Math.min(safeEngine.coinBalance(address(this)), safeEngine.debtBalance(address(this)));
    safeEngine.settleDebt(_debtToSettle);
  }

  /**
   * @notice Transfer any remaining surplus after the disable cooldown has passed. Meant to be a backup in case GlobalSettlement.processSAFE
   *              has a bug, governance doesn't have power over the system and there's still surplus left in the AccountingEngine
   *              which then blocks GlobalSettlement.setOutstandingCoinSupply.
   * @dev Transfer any remaining surplus after disableCooldown seconds have passed since disabling the contract
   *
   */
  function transferPostSettlementSurplus() external whenDisabled {
    if (block.timestamp < disableTimestamp + _params.disableCooldown) revert AccEng_PostSettlementCooldown();
    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _debtBalance = safeEngine.debtBalance(address(this));
    uint256 _debtToSettle = Math.min(_coinBalance, _debtBalance);
    safeEngine.settleDebt(_debtToSettle);
    _coinBalance -= _debtToSettle;
    _debtBalance -= _debtToSettle;
    if (_coinBalance > 0) safeEngine.transferInternalCoins(address(this), postSettlementSurplusDrain, _coinBalance);
    // NOTE: coinBalance should be 0 here
    // TODO: review events emission HAI-91
    emit TransferPostSettlementSurplus(
      postSettlementSurplusDrain, safeEngine.coinBalance(address(this)), safeEngine.debtBalance(address(this))
    );
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();
    address _address = _data.toAddress();

    // params
    if (_param == 'surplusIsTransferred') _params.surplusIsTransferred = _uint256;
    else if (_param == 'surplusDelay') _params.surplusDelay = _uint256;
    else if (_param == 'popDebtDelay') _params.popDebtDelay = _uint256;
    else if (_param == 'disableCooldown') _params.disableCooldown = _uint256;
    else if (_param == 'surplusAmount') _params.surplusAmount = _uint256;
    else if (_param == 'debtAuctionBidSize') _params.debtAuctionBidSize = _uint256;
    else if (_param == 'debtAuctionMintedTokens') _params.debtAuctionMintedTokens = _uint256;
    else if (_param == 'surplusBuffer') _params.surplusBuffer = _uint256;
    // registry
    else if (_param == 'surplusAuctionHouse') _setSurplusAuctionHouse(_address);
    else if (_param == 'debtAuctionHouse') debtAuctionHouse = IDebtAuctionHouse(_address);
    else if (_param == 'postSettlementSurplusDrain') postSettlementSurplusDrain = _address;
    else if (_param == 'extraSurplusReceiver') extraSurplusReceiver = _address;
    else revert UnrecognizedParam();
  }

  function _setSurplusAuctionHouse(address _surplusAuctionHouse) internal {
    safeEngine.denySAFEModification(address(surplusAuctionHouse));
    surplusAuctionHouse = ISurplusAuctionHouse(_surplusAuctionHouse);
    safeEngine.approveSAFEModification(_surplusAuctionHouse);
  }
}
