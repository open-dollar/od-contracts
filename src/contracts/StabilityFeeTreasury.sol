// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Math, RAY, HOUR} from '@libraries/Math.sol';

/**
 * @title  Stability Fee Treasury
 * @notice This contract is in charge of distributing the accrued stability fees to allowed addresses
 */
contract StabilityFeeTreasury is Authorizable, Modifiable, Disableable, IStabilityFeeTreasury {
  using Encoding for bytes;
  using Assertions for uint256;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc IStabilityFeeTreasury
  ISAFEEngine public safeEngine;
  /// @inheritdoc IStabilityFeeTreasury
  ISystemCoin public systemCoin;
  /// @inheritdoc IStabilityFeeTreasury
  ICoinJoin public coinJoin;
  /// @inheritdoc IStabilityFeeTreasury
  address public extraSurplusReceiver;

  // --- Params ---

  /// @inheritdoc IStabilityFeeTreasury
  // solhint-disable-next-line private-vars-leading-underscore
  StabilityFeeTreasuryParams public _params;

  /// @inheritdoc IStabilityFeeTreasury
  function params() external view returns (StabilityFeeTreasuryParams memory _sfTreasuryParams) {
    return _params;
  }

  // --- Data ---

  /// @inheritdoc IStabilityFeeTreasury
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(address _account => Allowance) public _allowance;

  /// @inheritdoc IStabilityFeeTreasury
  function allowance(address _account) external view returns (Allowance memory __allowance) {
    return _allowance[_account];
  }

  /// @inheritdoc IStabilityFeeTreasury
  mapping(address _account => mapping(uint256 _blockHour => uint256 _rad)) public pulledPerHour;
  /// @inheritdoc IStabilityFeeTreasury
  uint256 public latestSurplusTransferTime;

  /**
   * @notice Modifier to check if an account is not the treasury (this contract)
   * @param  _account The account to check whether it's the treasury or not
   * @dev    This modifier is used to prevent the treasury from giving funds to itself
   */
  modifier accountNotTreasury(address _account) {
    if (_account == address(this)) revert SFTreasury_AccountCannotBeTreasury();
    _;
  }

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _extraSurplusReceiver Address that receives surplus funds when treasury exceeds capacity
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _sfTreasuryParams Initial valid StabilityFeeTreasury parameters struct
   */
  constructor(
    address _safeEngine,
    address _extraSurplusReceiver,
    address _coinJoin,
    StabilityFeeTreasuryParams memory _sfTreasuryParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    coinJoin = ICoinJoin(_coinJoin.assertNonNull());
    extraSurplusReceiver = _extraSurplusReceiver;
    systemCoin = ISystemCoin(address(coinJoin.systemCoin()).assertNonNull());
    latestSurplusTransferTime = block.timestamp;
    _params = _sfTreasuryParams;

    systemCoin.approve(address(coinJoin), type(uint256).max);
  }

  // --- Shutdown ---

  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   * @inheritdoc Disableable
   */
  function _onContractDisable() internal override {
    _joinAllCoins();
    uint256 _coinBalanceSelf = safeEngine.coinBalance(address(this));
    safeEngine.transferInternalCoins(address(this), extraSurplusReceiver, _coinBalanceSelf);
  }

  /**
   * @notice Join all ERC20 system coins that the treasury has inside the SAFEEngine
   * @dev    Converts all ERC20 system coins to internal system coins
   */
  function _joinAllCoins() internal {
    uint256 _systemCoinBalance = systemCoin.balanceOf(address(this));
    if (_systemCoinBalance > 0) {
      coinJoin.join(address(this), _systemCoinBalance);
      emit JoinCoins(_systemCoinBalance);
    }
  }

  /// @inheritdoc IStabilityFeeTreasury
  function settleDebt() external returns (uint256 _coinBalance, uint256 _debtBalance) {
    return _settleDebt();
  }

  /**
   * @notice Settle as much bad debt as possible (if this contract has any)
   * @return _coinBalance Amount of internal system coins that this contract has after settling debt
   * @return _debtBalance Amount of bad debt that this contract has after settling debt
   */
  function _settleDebt() internal returns (uint256 _coinBalance, uint256 _debtBalance) {
    _coinBalance = safeEngine.coinBalance(address(this));
    _debtBalance = safeEngine.debtBalance(address(this));
    if (_debtBalance > 0) {
      uint256 _debtToSettle = Math.min(_coinBalance, _debtBalance);
      _coinBalance -= _debtToSettle;
      _debtBalance -= _debtToSettle;
      safeEngine.settleDebt(_debtToSettle);
      emit SettleDebt(_debtToSettle);
    }
  }

  // --- SF Transfer Allowance ---

  /// @inheritdoc IStabilityFeeTreasury
  function setTotalAllowance(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    _allowance[_account.assertNonNull()].total = _rad;
    emit SetTotalAllowance(_account, _rad);
  }

  /// @inheritdoc IStabilityFeeTreasury
  function setPerHourAllowance(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    _allowance[_account.assertNonNull()].perHour = _rad;
    emit SetPerHourAllowance(_account, _rad);
  }

  // --- Stability Fee Transfer (Governance) ---

  /// @inheritdoc IStabilityFeeTreasury
  function giveFunds(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    _account.assertNonNull();
    _joinAllCoins();
    (uint256 _coinBalance, uint256 _debtBalance) = _settleDebt();

    if (_debtBalance != 0) revert SFTreasury_OutstandingBadDebt();
    if (_coinBalance < _rad) revert SFTreasury_NotEnoughFunds();

    safeEngine.transferInternalCoins(address(this), _account, _rad);
    emit GiveFunds(_account, _rad);
  }

  /// @inheritdoc IStabilityFeeTreasury
  function takeFunds(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    safeEngine.transferInternalCoins(_account, address(this), _rad);
    emit TakeFunds(_account, _rad);
  }

  // --- Stability Fee Transfer (Approved Accounts) ---

  /// @inheritdoc IStabilityFeeTreasury
  function pullFunds(address _dstAccount, uint256 _wad) external {
    if (_dstAccount.assertNonNull() == address(this)) return;
    if (_dstAccount == extraSurplusReceiver) revert SFTreasury_DstCannotBeAccounting();
    if (_wad == 0) revert SFTreasury_NullTransferAmount();
    if (_allowance[msg.sender].total < _wad * RAY) revert SFTreasury_NotAllowed();
    if (_allowance[msg.sender].perHour > 0) {
      if (_allowance[msg.sender].perHour < pulledPerHour[msg.sender][block.timestamp / HOUR] + (_wad * RAY)) {
        revert SFTreasury_PerHourLimitExceeded();
      }
    }

    pulledPerHour[msg.sender][block.timestamp / HOUR] += (_wad * RAY);

    _joinAllCoins();
    (uint256 _coinBalance, uint256 _debtBalance) = _settleDebt();

    if (_debtBalance != 0) revert SFTreasury_OutstandingBadDebt();
    if (_coinBalance < _wad * RAY) revert SFTreasury_NotEnoughFunds();
    if (_coinBalance < _params.pullFundsMinThreshold) revert SFTreasury_BelowPullFundsMinThreshold();

    // Update allowance
    _allowance[msg.sender].total -= (_wad * RAY);

    // Transfer money
    safeEngine.transferInternalCoins(address(this), _dstAccount, _wad * RAY);

    emit PullFunds(msg.sender, _dstAccount, _wad * RAY);
  }

  // --- Treasury Maintenance ---

  /// @inheritdoc IStabilityFeeTreasury
  function transferSurplusFunds() external {
    if (block.timestamp < latestSurplusTransferTime + _params.surplusTransferDelay) {
      revert SFTreasury_TransferCooldownNotPassed();
    }
    // Join all coins in system
    _joinAllCoins();
    // Settle outstanding bad debt
    (uint256 _coinBalance, uint256 _debtBalance) = _settleDebt();

    // Check that there's no bad debt left
    if (_debtBalance != 0) revert SFTreasury_OutstandingBadDebt();
    // Check if we have too much money
    if (_coinBalance <= _params.treasuryCapacity) revert SFTreasury_NotEnoughSurplus();

    // Set internal vars
    latestSurplusTransferTime = block.timestamp;
    // Make sure that we still keep min SF in treasury
    uint256 _fundsToTransfer = _coinBalance - _params.treasuryCapacity;
    // Transfer surplus to accounting engine
    safeEngine.transferInternalCoins(address(this), extraSurplusReceiver, _fundsToTransfer);
    // Emit event
    emit TransferSurplusFunds(extraSurplusReceiver, _fundsToTransfer);
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'extraSurplusReceiver') extraSurplusReceiver = _data.toAddress();
    else if (_param == 'treasuryCapacity') _params.treasuryCapacity = _uint256;
    else if (_param == 'pullFundsMinThreshold') _params.pullFundsMinThreshold = _uint256;
    else if (_param == 'surplusTransferDelay') _params.surplusTransferDelay = _uint256;
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    extraSurplusReceiver.assertNonNull();
  }
}
