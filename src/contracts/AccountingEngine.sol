// SPDX-License-Identifier: GPL-3.0
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
import {Assertions} from '@libraries/Assertions.sol';

contract AccountingEngine is Authorizable, Modifiable, Disableable, IAccountingEngine {
  using Encoding for bytes;
  using Assertions for address;

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
  // solhint-disable-next-line private-vars-leading-underscore
  AccountingEngineParams public _params;

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
  constructor(
    address _safeEngine,
    address _surplusAuctionHouse,
    address _debtAuctionHouse,
    AccountingEngineParams memory _accEngineParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    _setSurplusAuctionHouse(_surplusAuctionHouse);
    debtAuctionHouse = IDebtAuctionHouse(_debtAuctionHouse);

    lastSurplusTime = block.timestamp;

    _params = _accEngineParams;
  }

  // --- Getters ---
  /**
   * @notice Returns the amount of bad debt that is not in the debtQueue and is not currently handled by debt auctions
   */
  function unqueuedUnauctionedDebt() external view returns (uint256 __unqueuedUnauctionedDebt) {
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

    emit PushDebtToQueue(block.timestamp, _debtBlock);
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
    debtQueue[_debtBlockTimestamp] = 0;

    emit PopDebtFromQueue(_debtBlockTimestamp, _debtBlock);
  }

  // Debt settlement
  /**
   * @notice Destroy an equal amount of coins and bad debt
   * @dev We can only destroy debt that is not locked in the queue and also not in a debt auction
   * @param _rad Amount of coins/debt to destroy (number with 45 decimals)
   */
  function settleDebt(uint256 _rad) external {
    _settleDebt(safeEngine.coinBalance(address(this)), safeEngine.debtBalance(address(this)), _rad);
  }

  function _settleDebt(
    uint256 _coinBalance,
    uint256 _debtBalance,
    uint256 _rad
  ) internal returns (uint256 _newCoinBalance, uint256 _newDebtBalance) {
    if (_rad > _coinBalance) revert AccEng_InsufficientSurplus();
    if (_rad > _unqueuedUnauctionedDebt(_debtBalance)) revert AccEng_InsufficientDebt();

    safeEngine.settleDebt(_rad);
    _newCoinBalance = _coinBalance - _rad;
    _newDebtBalance = _debtBalance - _rad;

    emit SettleDebt(_rad, _newCoinBalance, _newDebtBalance);
  }

  /**
   * @notice Use surplus coins to destroy debt that was in a debt auction
   * @param _rad Amount of coins/debt to destroy (number with 45 decimals)
   */
  function cancelAuctionedDebtWithSurplus(uint256 _rad) external {
    if (_rad > totalOnAuctionDebt) revert AccEng_InsufficientDebt();

    uint256 _coinBalance = safeEngine.coinBalance(address(this));

    if (_rad > _coinBalance) revert AccEng_InsufficientSurplus();

    safeEngine.settleDebt(_rad);
    totalOnAuctionDebt -= _rad;

    emit CancelDebt(_rad, _coinBalance - _rad, safeEngine.debtBalance(address(this)));
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

    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _debtBalance = safeEngine.debtBalance(address(this));

    if (_params.debtAuctionBidSize > _unqueuedUnauctionedDebt(_debtBalance)) revert AccEng_InsufficientDebt();

    (_coinBalance, _debtBalance) = _settleDebt(_coinBalance, _debtBalance, _coinBalance);
    totalOnAuctionDebt += _params.debtAuctionBidSize;

    _id = debtAuctionHouse.startAuction({
      _incomeReceiver: address(this),
      _amountToSell: _params.debtAuctionMintedTokens,
      _initialBid: _params.debtAuctionBidSize
    });

    emit AuctionDebt(_id, _params.debtAuctionMintedTokens, _params.debtAuctionBidSize);
  }

  // Surplus auction
  /**
   * @notice Start a surplus auction
   * @dev    We can only auction surplus if we wait at least 'surplusDelay' seconds since the last
   *         surplus auction trigger, if we keep enough surplus in the buffer and if there is no bad debt left to settle
   * @return _id the Id of the surplus auction that was started
   */
  function auctionSurplus() external returns (uint256 _id) {
    if (_params.surplusIsTransferred == 100) revert AccEng_SurplusAuctionDisabled();
    if (_params.surplusAmount == 0) revert AccEng_NullAmount();
    if (block.timestamp < lastSurplusTime + _params.surplusDelay) revert AccEng_SurplusCooldown();

    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _debtBalance = safeEngine.debtBalance(address(this));
    (_coinBalance, _debtBalance) = _settleDebt(_coinBalance, _debtBalance, _unqueuedUnauctionedDebt(_debtBalance));

    if (_coinBalance < _debtBalance + _params.surplusAmount + _params.surplusBuffer) {
      revert AccEng_InsufficientSurplus();
    }

    _id = surplusAuctionHouse.startAuction({_amountToSell: _params.surplusAmount * (100 - _params.surplusIsTransferred) / 100, _initialBid: 0});

    lastSurplusTime = block.timestamp;
    emit AuctionSurplus(_id, 0, _params.surplusAmount * (100 - _params.surplusIsTransferred) / 100);

    //Transfer remaining surplus percentage
    if(_params.surplusIsTransferred > 0){
      if (extraSurplusReceiver == address(0)) revert AccEng_NullSurplusReceiver();

      safeEngine.transferInternalCoins({
        _source: address(this),
        _destination: extraSurplusReceiver,
        _rad: _params.surplusAmount * _params.surplusIsTransferred / 100
      });

      lastSurplusTime = block.timestamp;
      emit TransferSurplus(extraSurplusReceiver, _params.surplusAmount * _params.surplusIsTransferred / 100);
    }
  }

  // Extra surplus transfers/surplus auction alternative
  /**
   * @notice Send surplus to an address as an alternative to surplus auctions
   * @dev    We can only transfer surplus if we wait at least 'surplusDelay' seconds since the last
   *           transfer, if we keep enough surplus in the buffer and if there is no bad debt left to settle
   */
  function transferExtraSurplus() external {
    if (_params.surplusIsTransferred <= 0) revert AccEng_SurplusTransferDisabled();
    if (extraSurplusReceiver == address(0)) revert AccEng_NullSurplusReceiver();
    if (_params.surplusAmount == 0) revert AccEng_NullAmount();
    if (block.timestamp < lastSurplusTime + _params.surplusDelay) revert AccEng_SurplusCooldown();

    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _debtBalance = safeEngine.debtBalance(address(this));
    (_coinBalance, _debtBalance) = _settleDebt(_coinBalance, _debtBalance, _unqueuedUnauctionedDebt(_debtBalance));

    if (_coinBalance < _debtBalance + _params.surplusAmount + _params.surplusBuffer) {
      revert AccEng_InsufficientSurplus();
    }

    safeEngine.transferInternalCoins({
      _source: address(this),
      _destination: extraSurplusReceiver,
      _rad: _params.surplusAmount * _params.surplusIsTransferred / 100
    });

    lastSurplusTime = block.timestamp;
    emit TransferSurplus(extraSurplusReceiver, _params.surplusAmount * _params.surplusIsTransferred / 100);

    //auction remaining surplus percentage
    if(_params.surplusIsTransferred < 100){
      uint _id = surplusAuctionHouse.startAuction({_amountToSell: _params.surplusAmount * (100 - _params.surplusIsTransferred) / 100, _initialBid: 0});

      lastSurplusTime = block.timestamp;
      emit AuctionSurplus(_id, 0, _params.surplusAmount * (100 - _params.surplusIsTransferred) / 100);
    }
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
    if (address(postSettlementSurplusDrain) == address(0)) revert AccEng_NullSurplusReceiver();
    if (block.timestamp < disableTimestamp + _params.disableCooldown) revert AccEng_PostSettlementCooldown();

    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _debtBalance = safeEngine.debtBalance(address(this));
    uint256 _debtToSettle = Math.min(_coinBalance, _debtBalance);
    (_coinBalance,) = _settleDebt(_coinBalance, _debtBalance, _debtToSettle);

    if (_coinBalance > 0) {
      safeEngine.transferInternalCoins({
        _source: address(this),
        _destination: postSettlementSurplusDrain,
        _rad: _coinBalance
      });

      emit TransferSurplus(postSettlementSurplusDrain, _coinBalance);
    }
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
    if (address(surplusAuctionHouse) != address(0)) {
      safeEngine.denySAFEModification(address(surplusAuctionHouse));
    }
    surplusAuctionHouse = ISurplusAuctionHouse(_surplusAuctionHouse);
    safeEngine.approveSAFEModification(_surplusAuctionHouse);
  }

  function _validateParameters() internal view override {
    address(surplusAuctionHouse).assertNonNull();
    address(debtAuctionHouse).assertNonNull();
  }
}
