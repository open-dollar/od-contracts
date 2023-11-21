// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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

/**
 * @title  AccountingEngine
 * @notice This contract is responsible for handling protocol surplus and debt
 * @notice It allows the system to auction surplus and debt, as well as transfer surplus
 * @dev    This is a system contract, therefore it is not meant to be used by users directly
 */
contract AccountingEngine is Authorizable, Modifiable, Disableable, IAccountingEngine {
  using Encoding for bytes;
  using Assertions for address;

  // --- Auth ---

  /**
   * @notice Overriding method allows new authorizations only if the contract is enabled
   * @param  _account The account to authorize
   * @inheritdoc IAuthorizable
   */
  function addAuthorization(address _account) external override(Authorizable, IAuthorizable) isAuthorized whenEnabled {
    _addAuthorization(_account);
  }

  // --- Registry ---

  /// @inheritdoc IAccountingEngine
  ISAFEEngine public safeEngine;
  /// @inheritdoc IAccountingEngine
  ISurplusAuctionHouse public surplusAuctionHouse;
  /// @inheritdoc IAccountingEngine
  IDebtAuctionHouse public debtAuctionHouse;
  /// @inheritdoc IAccountingEngine
  address public postSettlementSurplusDrain;
  /// @inheritdoc IAccountingEngine
  address public extraSurplusReceiver;

  // --- Params ---

  /// @inheritdoc IAccountingEngine
  // solhint-disable-next-line private-vars-leading-underscore
  AccountingEngineParams public _params;

  /// @inheritdoc IAccountingEngine
  function params() external view returns (AccountingEngineParams memory _accEngineParams) {
    return _params;
  }

  // --- Data ---

  /// @inheritdoc IAccountingEngine
  mapping(uint256 _timestamp => uint256 _rad) public debtQueue;
  /// @inheritdoc IAccountingEngine
  uint256 public /* RAD */ totalOnAuctionDebt;
  /// @inheritdoc IAccountingEngine
  uint256 public /* RAD */ totalQueuedDebt;
  /// @inheritdoc IAccountingEngine
  uint256 public lastSurplusTime;
  /// @inheritdoc IAccountingEngine
  uint256 public disableTimestamp;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine
   * @param  _surplusAuctionHouse Address of the SurplusAuctionHouse
   * @param  _debtAuctionHouse Address of the DebtAuctionHouse
   * @param  _accEngineParams Initial valid AccountingEngine parameters struct
   */
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

  /// @inheritdoc IAccountingEngine
  function unqueuedUnauctionedDebt() external view returns (uint256 __unqueuedUnauctionedDebt) {
    return _unqueuedUnauctionedDebt(safeEngine.debtBalance(address(this)));
  }

  function _unqueuedUnauctionedDebt(uint256 _debtBalance) internal view returns (uint256 __unqueuedUnauctionedDebt) {
    return (_debtBalance - totalQueuedDebt) - totalOnAuctionDebt;
  }

  // --- Debt Queueing ---

  /// @inheritdoc IAccountingEngine
  function pushDebtToQueue(uint256 _debtBlock) external isAuthorized {
    debtQueue[block.timestamp] = debtQueue[block.timestamp] + _debtBlock;
    totalQueuedDebt = totalQueuedDebt + _debtBlock;

    emit PushDebtToQueue(block.timestamp, _debtBlock);
  }

  /// @inheritdoc IAccountingEngine
  function popDebtFromQueue(uint256 _debtBlockTimestamp) external {
    if (block.timestamp < _debtBlockTimestamp + _params.popDebtDelay) revert AccEng_PopDebtCooldown();

    uint256 _debtBlock = debtQueue[_debtBlockTimestamp];

    if (_debtBlock == 0) revert AccEng_NullAmount();

    totalQueuedDebt = totalQueuedDebt - _debtBlock;
    debtQueue[_debtBlockTimestamp] = 0;

    emit PopDebtFromQueue(_debtBlockTimestamp, _debtBlock);
  }

  // Debt settlement

  /// @inheritdoc IAccountingEngine
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

  /// @inheritdoc IAccountingEngine
  function cancelAuctionedDebtWithSurplus(uint256 _rad) external {
    if (_rad > totalOnAuctionDebt) revert AccEng_InsufficientDebt();

    uint256 _coinBalance = safeEngine.coinBalance(address(this));

    if (_rad > _coinBalance) revert AccEng_InsufficientSurplus();

    safeEngine.settleDebt(_rad);
    totalOnAuctionDebt -= _rad;

    emit CancelDebt(_rad, _coinBalance - _rad, safeEngine.debtBalance(address(this)));
  }

  // Debt auction

  /// @inheritdoc IAccountingEngine
  function auctionDebt() external returns (uint256 _id) {
    if (_params.debtAuctionBidSize == 0) revert AccEng_DebtAuctionDisabled();

    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _debtBalance = safeEngine.debtBalance(address(this));
    (_coinBalance, _debtBalance) = _settleDebt(_coinBalance, _debtBalance, _coinBalance);

    if (_params.debtAuctionBidSize > _unqueuedUnauctionedDebt(_debtBalance)) revert AccEng_InsufficientDebt();

    totalOnAuctionDebt += _params.debtAuctionBidSize;
    _id = debtAuctionHouse.startAuction({
      _incomeReceiver: address(this),
      _amountToSell: _params.debtAuctionMintedTokens,
      _initialBid: _params.debtAuctionBidSize
    });

    emit AuctionDebt(_id, _params.debtAuctionMintedTokens, _params.debtAuctionBidSize);
  }

  // Surplus auction

  /// @inheritdoc IAccountingEngine
  function auctionSurplus() external returns (uint256 _id) {
    if (_params.surplusIsTransferred == 1) revert AccEng_SurplusAuctionDisabled();
    if (_params.surplusAmount == 0) revert AccEng_NullAmount();
    if (block.timestamp < lastSurplusTime + _params.surplusDelay) revert AccEng_SurplusCooldown();

    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    uint256 _debtBalance = safeEngine.debtBalance(address(this));
    (_coinBalance, _debtBalance) = _settleDebt(_coinBalance, _debtBalance, _unqueuedUnauctionedDebt(_debtBalance));

    if (_coinBalance < _debtBalance + _params.surplusAmount + _params.surplusBuffer) {
      revert AccEng_InsufficientSurplus();
    }

    _id = surplusAuctionHouse.startAuction({_amountToSell: _params.surplusAmount, _initialBid: 0});

    lastSurplusTime = block.timestamp;
    emit AuctionSurplus(_id, 0, _params.surplusAmount);
  }

  // Extra surplus transfers/surplus auction alternative

  /// @inheritdoc IAccountingEngine
  function transferExtraSurplus() external {
    if (_params.surplusIsTransferred != 1) revert AccEng_SurplusTransferDisabled();
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
      _rad: _params.surplusAmount
    });

    lastSurplusTime = block.timestamp;
    emit TransferSurplus(extraSurplusReceiver, _params.surplusAmount);
  }

  // --- Shutdown ---

  /**
   * @notice Runtime to be run when the contract is disabled (normally triggered by GlobalSettlement)
   * @dev When it's being disabled, the contract will record the current timestamp. Afterwards,
   *      the contract tries to settle as much debt as possible (if there's any) with any surplus that's
   *      left in the AccountingEngine
   * @inheritdoc Disableable
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

  /// @inheritdoc IAccountingEngine
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

  /// @inheritdoc Modifiable
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

  /// @dev Set the surplus auction house, deny permissions on the old one and approve on the new one
  function _setSurplusAuctionHouse(address _surplusAuctionHouse) internal {
    if (address(surplusAuctionHouse) != address(0)) {
      safeEngine.denySAFEModification(address(surplusAuctionHouse));
    }
    surplusAuctionHouse = ISurplusAuctionHouse(_surplusAuctionHouse);
    safeEngine.approveSAFEModification(_surplusAuctionHouse);
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(surplusAuctionHouse).assertHasCode();
    address(debtAuctionHouse).assertHasCode();
  }
}
