// SPDX-License-Identifier: GPL-3.0
/// StabilityFeeTreasury.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>, 2020 Reflexer Labs, INC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {Math, RAY, HUNDRED} from '@libraries/Math.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {ISystemCoin as SystemCoinLike} from '@interfaces/external/ISystemCoin.sol';
import {ICoinJoin as CoinJoinLike} from '@interfaces/ICoinJoin.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contract-utils/Disableable.sol';

contract StabilityFeeTreasury is Authorizable, Disableable, IStabilityFeeTreasury {
  // Mapping of total and per block allowances
  mapping(address => Allowance) public allowance;
  // Mapping that keeps track of how much surplus an authorized address has pulled each block
  mapping(address => mapping(uint256 => uint256)) public pulledPerBlock;

  SAFEEngineLike public safeEngine;
  SystemCoinLike public systemCoin;
  CoinJoinLike public coinJoin;

  // The address that receives any extra surplus which is not used by the treasury
  address public extraSurplusReceiver;

  uint256 public treasuryCapacity; // max amount of SF that can be kept in the treasury                        [rad]
  uint256 public minimumFundsRequired; // minimum amount of SF that must be kept in the treasury at all times      [rad]
  uint256 public expensesMultiplier; // multiplier for expenses                                                  [hundred]
  uint256 public surplusTransferDelay; // minimum time between transferSurplusFunds calls                          [seconds]
  uint256 public expensesAccumulator; // expenses accumulator                                                     [rad]
  uint256 public accumulatorTag; // latest tagged accumulator price                                          [rad]
  uint256 public pullFundsMinThreshold; // minimum funds that must be in the treasury so that someone can pullFunds [rad]
  uint256 public latestSurplusTransferTime; // latest timestamp when transferSurplusFunds was called                    [seconds]

  modifier accountNotTreasury(address account) {
    require(account != address(this), 'StabilityFeeTreasury/account-cannot-be-treasury');
    _;
  }

  constructor(address _safeEngine, address _extraSurplusReceiver, address _coinJoin) Authorizable(msg.sender) {
    require(address(CoinJoinLike(_coinJoin).systemCoin()) != address(0), 'StabilityFeeTreasury/null-system-coin');
    require(_extraSurplusReceiver != address(0), 'StabilityFeeTreasury/null-surplus-receiver');

    safeEngine = SAFEEngineLike(_safeEngine);
    extraSurplusReceiver = _extraSurplusReceiver;
    coinJoin = CoinJoinLike(_coinJoin);
    systemCoin = SystemCoinLike(coinJoin.systemCoin());
    latestSurplusTransferTime = block.timestamp;
    expensesMultiplier = HUNDRED;

    systemCoin.approve(address(coinJoin), type(uint256).max);
  }

  // --- Administration ---
  /**
   * @notice Modify address parameters
   * @param  _parameter The name of the contract whose address will be changed
   * @param  _addr New address for the contract
   */
  function modifyParameters(bytes32 _parameter, address _addr) external isAuthorized whenEnabled {
    require(_addr != address(0), 'StabilityFeeTreasury/null-addr');
    if (_parameter == 'extraSurplusReceiver') {
      require(_addr != address(this), 'StabilityFeeTreasury/accounting-engine-cannot-be-treasury');
      extraSurplusReceiver = _addr;
    } else {
      revert('StabilityFeeTreasury/modify-unrecognized-param');
    }
    emit ModifyParameters(_parameter, _addr);
  }

  /**
   * @notice Modify uint256 parameters
   * @param  _parameter The name of the parameter to modify
   * @param  _val New parameter value
   */
  function modifyParameters(bytes32 _parameter, uint256 _val) external isAuthorized whenEnabled {
    if (_parameter == 'expensesMultiplier') {
      expensesMultiplier = _val;
    } else if (_parameter == 'treasuryCapacity') {
      require(_val >= minimumFundsRequired, 'StabilityFeeTreasury/capacity-lower-than-min-funds');
      treasuryCapacity = _val;
    } else if (_parameter == 'minimumFundsRequired') {
      require(_val <= treasuryCapacity, 'StabilityFeeTreasury/min-funds-higher-than-capacity');
      minimumFundsRequired = _val;
    } else if (_parameter == 'pullFundsMinThreshold') {
      pullFundsMinThreshold = _val;
    } else if (_parameter == 'surplusTransferDelay') {
      surplusTransferDelay = _val;
    } else {
      revert('StabilityFeeTreasury/modify-unrecognized-param');
    }
    emit ModifyParameters(_parameter, _val);
  }

  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */
  function disableContract() external isAuthorized whenEnabled {
    _disableContract();
    _joinAllCoins();
    safeEngine.transferInternalCoins(address(this), extraSurplusReceiver, safeEngine.coinBalance(address(this)));
  }

  /**
   * @notice Join all ERC20 system coins that the treasury has inside the SAFEEngine
   */
  function _joinAllCoins() internal virtual {
    if (systemCoin.balanceOf(address(this)) > 0) {
      coinJoin.join(address(this), systemCoin.balanceOf(address(this)));
    }
  }

  /**
   * @notice Settle as much bad debt as possible (if this contract has any)
   */
  function settleDebt() external virtual {
    _settleDebt();
  }

  function _settleDebt() internal virtual {
    uint256 coinBalanceSelf = safeEngine.coinBalance(address(this));
    uint256 debtBalanceSelf = safeEngine.debtBalance(address(this));

    if (debtBalanceSelf > 0) {
      safeEngine.settleDebt(Math.min(coinBalanceSelf, debtBalanceSelf));
    }
  }

  // --- SF Transfer Allowance ---
  /**
   * @notice Modify an address' total allowance in order to withdraw SF from the treasury
   * @param  _account The approved address
   * @param  _rad The total approved amount of SF to withdraw (number with 45 decimals)
   */
  function setTotalAllowance(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    require(_account != address(0), 'StabilityFeeTreasury/null-account');
    allowance[_account].total = _rad;
    emit SetTotalAllowance(_account, _rad);
  }

  /**
   * @notice Modify an address' per block allowance in order to withdraw SF from the treasury
   * @param  _account The approved address
   * @param  _rad The per block approved amount of SF to withdraw (number with 45 decimals)
   */
  function setPerBlockAllowance(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    require(_account != address(0), 'StabilityFeeTreasury/null-account');
    allowance[_account].perBlock = _rad;
    emit SetPerBlockAllowance(_account, _rad);
  }

  // --- Stability Fee Transfer (Governance) ---
  /**
   * @notice Governance transfers SF to an address
   * @param  _account Address to transfer SF to
   * @param  _rad Amount of internal system coins to transfer (a number with 45 decimals)
   */
  function giveFunds(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    require(_account != address(0), 'StabilityFeeTreasury/null-account');

    _joinAllCoins();
    _settleDebt();

    require(safeEngine.debtBalance(address(this)) == 0, 'StabilityFeeTreasury/outstanding-bad-debt');
    require(safeEngine.coinBalance(address(this)) >= _rad, 'StabilityFeeTreasury/not-enough-funds');

    if (_account != extraSurplusReceiver) {
      expensesAccumulator += _rad;
    }

    safeEngine.transferInternalCoins(address(this), _account, _rad);
    emit GiveFunds(_account, _rad, expensesAccumulator);
  }

  /**
   * @notice Governance takes funds from an address
   * @param  _account Address to take system coins from
   * @param  _rad Amount of internal system coins to take from the account (a number with 45 decimals)
   */
  function takeFunds(address _account, uint256 _rad) external isAuthorized accountNotTreasury(_account) {
    safeEngine.transferInternalCoins(_account, address(this), _rad);
    emit TakeFunds(_account, _rad);
  }

  // --- Stability Fee Transfer (Approved Accounts) ---
  /**
   * @notice Pull stability fees from the treasury (if your allowance permits)
   * @param  _dstAccount Address to transfer funds to
   * @param  _token Address of the token to transfer (in this case it must be the address of the ERC20 system coin).
   *              Used only to adhere to a standard for automated, on-chain treasuries
   * @param  _wad Amount of system coins (SF) to transfer (expressed as an 18 decimal number but the contract will transfer
   *             internal system coins that have 45 decimals)
   */
  function pullFunds(address _dstAccount, address _token, uint256 _wad) external {
    if (_dstAccount == address(this)) return;
    require(allowance[msg.sender].total >= _wad * RAY, 'StabilityFeeTreasury/not-allowed');
    require(_dstAccount != address(0), 'StabilityFeeTreasury/null-dst');
    require(_dstAccount != extraSurplusReceiver, 'StabilityFeeTreasury/dst-cannot-be-accounting');
    require(_wad > 0, 'StabilityFeeTreasury/null-transfer-amount');
    require(_token == address(systemCoin), 'StabilityFeeTreasury/token-unavailable');
    if (allowance[msg.sender].perBlock > 0) {
      require(
        pulledPerBlock[msg.sender][block.number] + (_wad * RAY) <= allowance[msg.sender].perBlock,
        'StabilityFeeTreasury/per-block-limit-exceeded'
      );
    }

    pulledPerBlock[msg.sender][block.number] += (_wad * RAY);

    _joinAllCoins();
    _settleDebt();

    require(safeEngine.debtBalance(address(this)) == 0, 'StabilityFeeTreasury/outstanding-bad-debt');
    require(safeEngine.coinBalance(address(this)) >= _wad * RAY, 'StabilityFeeTreasury/not-enough-funds');
    require(
      safeEngine.coinBalance(address(this)) >= pullFundsMinThreshold,
      'StabilityFeeTreasury/below-pullFunds-min-threshold'
    );

    // Update allowance and accumulator
    allowance[msg.sender].total -= (_wad * RAY);
    expensesAccumulator += (_wad * RAY);

    // Transfer money
    safeEngine.transferInternalCoins(address(this), _dstAccount, _wad * RAY);

    emit PullFunds(msg.sender, _dstAccount, _token, _wad * RAY, expensesAccumulator);
  }

  // --- Treasury Maintenance ---
  /**
   * @notice Transfer surplus stability fees to the extraSurplusReceiver. This is here to make sure that the treasury
   *              doesn't accumulate fees that it doesn't even need in order to pay for allowances. It ensures
   *              that there are enough funds left in the treasury to account for projected expenses (latest expenses multiplied
   *              by an expense multiplier)
   */
  function transferSurplusFunds() external {
    require(
      block.timestamp >= latestSurplusTransferTime + surplusTransferDelay,
      'StabilityFeeTreasury/transfer-cooldown-not-passed'
    );
    // Compute latest expenses
    uint256 _latestExpenses = expensesAccumulator - accumulatorTag;
    // Check if we need to keep more funds than the total capacity
    uint256 _remainingFunds = (treasuryCapacity <= expensesMultiplier * _latestExpenses / HUNDRED)
      ? expensesMultiplier * _latestExpenses / HUNDRED
      : treasuryCapacity;
    // Make sure to keep at least minimum funds
    _remainingFunds =
      (expensesMultiplier * _latestExpenses / HUNDRED <= minimumFundsRequired) ? minimumFundsRequired : _remainingFunds;
    // Set internal vars
    accumulatorTag = expensesAccumulator;
    latestSurplusTransferTime = block.timestamp;
    // Join all coins in system
    _joinAllCoins();
    // Settle outstanding bad debt
    _settleDebt();
    // Check that there's no bad debt left
    require(safeEngine.debtBalance(address(this)) == 0, 'StabilityFeeTreasury/outstanding-bad-debt');
    // Check if we have too much money
    if (safeEngine.coinBalance(address(this)) > _remainingFunds) {
      // Make sure that we still keep min SF in treasury
      uint256 fundsToTransfer = safeEngine.coinBalance(address(this)) - _remainingFunds;
      // Transfer surplus to accounting engine
      safeEngine.transferInternalCoins(address(this), extraSurplusReceiver, fundsToTransfer);
      // Emit event
      emit TransferSurplusFunds(extraSurplusReceiver, fundsToTransfer);
    }
  }
}
