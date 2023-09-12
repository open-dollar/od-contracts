// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingJob} from '@interfaces/jobs/IAccountingJob.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';

import {Job} from '@contracts/jobs/Job.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';

contract AccountingJob is Job, Authorizable, Modifiable, IAccountingJob {
  using Encoding for bytes;

  // --- Data ---
  bool public shouldWorkPopDebtFromQueue;
  bool public shouldWorkAuctionDebt;
  bool public shouldWorkAuctionSurplus;
  bool public shouldWorkTransferExtraSurplus;

  // --- Registry ---
  IAccountingEngine public accountingEngine;

  // --- Init ---
  constructor(
    address _accountingEngine,
    address _stabilityFeeTreasury,
    uint256 _rewardAmount
  ) Job(_stabilityFeeTreasury, _rewardAmount) Authorizable(msg.sender) {
    accountingEngine = IAccountingEngine(_accountingEngine);

    shouldWorkPopDebtFromQueue = true;
    shouldWorkAuctionDebt = true;
    shouldWorkAuctionSurplus = true;
    shouldWorkTransferExtraSurplus = true;
  }

  // --- Job ---
  function workPopDebtFromQueue(uint256 _debtBlockTimestamp) external reward {
    if (!shouldWorkPopDebtFromQueue) revert NotWorkable();
    accountingEngine.popDebtFromQueue(_debtBlockTimestamp);
  }

  function workAuctionDebt() external reward {
    if (!shouldWorkAuctionDebt) revert NotWorkable();
    accountingEngine.auctionDebt();
  }

  function workAuctionSurplus() external reward {
    if (!shouldWorkAuctionSurplus) revert NotWorkable();
    accountingEngine.auctionSurplus();
  }

  function workTransferExtraSurplus() external reward {
    if (!shouldWorkTransferExtraSurplus) revert NotWorkable();
    accountingEngine.transferExtraSurplus();
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    bool _bool = _data.toBool();

    if (_param == 'accountingEngine') accountingEngine = IAccountingEngine(_address);
    else if (_param == 'stabilityFeeTreasury') stabilityFeeTreasury = IStabilityFeeTreasury(_address);
    else if (_param == 'shouldWorkPopDebtFromQueue') shouldWorkPopDebtFromQueue = _bool;
    else if (_param == 'shouldWorkAuctionDebt') shouldWorkAuctionDebt = _bool;
    else if (_param == 'shouldWorkAuctionSurplus') shouldWorkAuctionSurplus = _bool;
    else if (_param == 'shouldWorkTransferExtraSurplus') shouldWorkTransferExtraSurplus = _bool;
    else if (_param == 'rewardAmount') rewardAmount = _data.toUint256();
    else revert UnrecognizedParam();
  }
}
