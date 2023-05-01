// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/ICoinJoin.sol';
import {ISystemCoin} from '@interfaces/external/ISystemCoin.sol';

interface IStabilityFeeTreasury is IAuthorizable, IDisableable {
  // --- Events ---
  event ModifyParameters(bytes32 parameter, address addr);
  event ModifyParameters(bytes32 parameter, uint256 val);
  event SetTotalAllowance(address indexed _account, uint256 _rad);
  event SetPerBlockAllowance(address indexed account, uint256 rad);
  event GiveFunds(address indexed _account, uint256 _rad, uint256 _expensesAccumulator);
  event TakeFunds(address indexed _account, uint256 _rad);
  event PullFunds(
    address indexed _sender, address indexed _dstAccount, address _token, uint256 _rad, uint256 _expensesAccumulator
  );
  event TransferSurplusFunds(address _extraSurplusReceiver, uint256 _fundsToTransfer);

  // --- Structs ---
  struct Allowance {
    uint256 total;
    uint256 perBlock;
  }

  function setTotalAllowance(address _account, uint256 _rad) external;
  function setPerBlockAllowance(address _account, uint256 _rad) external;
  function giveFunds(address _account, uint256 _rad) external;
  function takeFunds(address _account, uint256 _rad) external;
  function pullFunds(address _destinationAccount, address _token, uint256 _wad) external;
  function transferSurplusFunds() external;
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function coinJoin() external view returns (ICoinJoin _coinJoin);
  function extraSurplusReceiver() external view returns (address _extraSurplusReceiver);
  function systemCoin() external view returns (ISystemCoin _systemCoin);
  function latestSurplusTransferTime() external view returns (uint256 _latestSurplusTransferTime);
  function expensesMultiplier() external view returns (uint256 _expensesMultiplier);
  function settleDebt() external;
  function allowance(address _account) external view returns (uint256 _total, uint256 _perBlock);
  function expensesAccumulator() external view returns (uint256 _expensesAccumulator);
  function pulledPerBlock(address _account, uint256 _blockNumber) external view returns (uint256 _pulledPerBlock);
  function pullFundsMinThreshold() external view returns (uint256 _pullFundsMinThreshold);
  function treasuryCapacity() external view returns (uint256 _treasuryCapacity);
  function accumulatorTag() external view returns (uint256 _accumulatorTag);
  function minimumFundsRequired() external view returns (uint256 _minimumFundsRequired);
  function surplusTransferDelay() external view returns (uint256 _surplusTransferDelay);
}