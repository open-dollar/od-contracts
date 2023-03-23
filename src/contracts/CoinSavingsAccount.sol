// SPDX-License-Identifier: GPL-3.0
/// CoinSavingsAccount.sol

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

/*
   "Savings Coin" is obtained when the core coin created by the protocol
   is deposited into this contract. Each "Savings Coin" accrues interest
   at the "Savings Rate". This contract does not implement a user tradeable token
   and is intended to be used with adapters.
         --- `save` your `coin` in the `savings account` ---
   - `savingsRate`: the Savings Rate
   - `savings`: user balance of Savings Coins
   - `deposit`: start saving some coins
   - `withdraw`: withdraw coins from the savings account
   - `updateAccumulatedRate`: perform rate collection*/

import {ISAFEEngine as SAFEEngineLike} from '../interfaces/ISAFEEngine.sol';

import {Math} from './utils/Math.sol';

contract CoinSavingsAccount is Math {
  // --- Auth ---
  mapping(address => uint256) public authorizedAccounts;
  /**
   * @notice Add auth to an account
   * @param account Account to add auth to
   */

  function addAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 1;
    emit AddAuthorization(account);
  }
  /**
   * @notice Remove auth from an account
   * @param account Account to remove auth from
   */

  function removeAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 0;
    emit RemoveAuthorization(account);
  }
  /**
   * @notice Checks whether msg.sender can call an authed function
   *
   */

  modifier isAuthorized() {
    require(authorizedAccounts[msg.sender] == 1, 'CoinSavingsAccount/account-not-authorized');
    _;
  }

  // --- Events ---
  event AddAuthorization(address account);
  event RemoveAuthorization(address account);
  event ModifyParameters(bytes32 parameter, uint256 data);
  event ModifyParameters(bytes32 parameter, address data);
  event DisableContract();
  event Deposit(address indexed usr, uint256 balance, uint256 totalSavings);
  event Withdraw(address indexed usr, uint256 balance, uint256 totalSavings);
  event UpdateAccumulatedRate(uint256 newAccumulatedRate, uint256 coinAmount);

  // --- Data ---
  // Amount of coins each user has deposited
  mapping(address => uint256) public savings;

  // Total amount of coins deposited
  uint256 public totalSavings;
  // Per second savings rate
  uint256 public savingsRate;
  // An index representing total accumulated rates
  uint256 public accumulatedRate;

  // SAFE database
  SAFEEngineLike public safeEngine;
  // Accounting engine
  address public accountingEngine;
  // When accumulated rates were last updated
  uint256 public latestUpdateTime;
  // Whether this contract is enabled or not
  uint256 public contractEnabled;

  // --- Init ---
  constructor(address _safeEngine) {
    authorizedAccounts[msg.sender] = 1;
    safeEngine = SAFEEngineLike(_safeEngine);
    savingsRate = RAY;
    accumulatedRate = RAY;
    latestUpdateTime = block.timestamp;
    contractEnabled = 1;
  }

  // --- Administration ---
  /**
   * @notice Modify an uint256 parameter
   * @param parameter The name of the parameter modified
   * @param data New value for the parameter
   */
  function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
    require(contractEnabled == 1, 'CoinSavingsAccount/contract-not-enabled');
    require(block.timestamp == latestUpdateTime, 'CoinSavingsAccount/accumulation-time-not-updated');
    if (parameter == 'savingsRate') savingsRate = data;
    else revert('CoinSavingsAccount/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }
  /**
   * @notice Modify the address of the accountingEngine
   * @param parameter The name of the parameter modified
   * @param addr New value for the parameter
   */

  function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
    if (parameter == 'accountingEngine') accountingEngine = addr;
    else revert('CoinSavingsAccount/modify-unrecognized-param');
    emit ModifyParameters(parameter, addr);
  }
  /**
   * @notice Disable this contract (usually called by Global Settlement)
   */

  function disableContract() external isAuthorized {
    contractEnabled = 0;
    savingsRate = RAY;
    emit DisableContract();
  }

  // --- Savings Rate Accumulation ---
  /**
   * @notice Update the accumulated rate index
   * @dev We return early if 'latestUpdateTime' is greater than or equal to block.timestamp. When the savings
   *           rate is positive, we create unbacked debt for the accountingEngine and issue new coins for
   *           this contract
   */
  function updateAccumulatedRate() public returns (uint256 newAccumulatedRate) {
    if (block.timestamp <= latestUpdateTime) return accumulatedRate;
    newAccumulatedRate =
      rmultiply(rpower(savingsRate, subtract(block.timestamp, latestUpdateTime), RAY), accumulatedRate);
    uint256 accumulatedRate_ = subtract(newAccumulatedRate, accumulatedRate);
    accumulatedRate = newAccumulatedRate;
    latestUpdateTime = block.timestamp;
    safeEngine.createUnbackedDebt(address(accountingEngine), address(this), multiply(totalSavings, accumulatedRate_));
    emit UpdateAccumulatedRate(newAccumulatedRate, multiply(totalSavings, accumulatedRate_));
  }
  /**
   * @notice Get the next value of 'accumulatedRate' without actually updating the variable
   */

  function nextAccumulatedRate() external view returns (uint256) {
    if (block.timestamp <= latestUpdateTime) return accumulatedRate;
    return rmultiply(rpower(savingsRate, subtract(block.timestamp, latestUpdateTime), RAY), accumulatedRate);
  }

  // --- Savings Management ---
  /**
   * @notice Deposit coins in the savings account
   * @param wad Amount of coins to deposit (expressed as an 18 decimal number). 'wad' will be multiplied by
   *             'accumulatedRate' (27 decimals) to result in a correct amount of internal coins to transfer
   */
  function deposit(uint256 wad) external {
    updateAccumulatedRate();
    require(block.timestamp == latestUpdateTime, 'CoinSavingsAccount/accumulation-time-not-updated');
    savings[msg.sender] = addition(savings[msg.sender], wad);
    totalSavings = addition(totalSavings, wad);
    safeEngine.transferInternalCoins(msg.sender, address(this), multiply(accumulatedRate, wad));
    emit Deposit(msg.sender, savings[msg.sender], totalSavings);
  }
  /**
   * @notice Withdraw coins (alongside any interest accrued) from the savings account
   * @param wad Amount of coins to withdraw (expressed as an 18 decimal number). 'wad' will be multiplied by
   *             'accumulatedRate' (27 decimals) to result in a correct amount of internal coins to transfer
   */

  function withdraw(uint256 wad) external {
    updateAccumulatedRate();
    savings[msg.sender] = subtract(savings[msg.sender], wad);
    totalSavings = subtract(totalSavings, wad);
    safeEngine.transferInternalCoins(address(this), msg.sender, multiply(accumulatedRate, wad));
    emit Withdraw(msg.sender, savings[msg.sender], totalSavings);
  }
}
