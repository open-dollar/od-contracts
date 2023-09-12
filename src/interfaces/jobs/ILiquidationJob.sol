// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';

import {IJob} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ILiquidationJob is IJob, IAuthorizable, IModifiable {
  // --- Data ---
  function shouldWork() external view returns (bool _shouldWork);

  // --- Registry ---
  function liquidationEngine() external view returns (ILiquidationEngine _liquidationEngine);

  // --- Job ---
  function workLiquidation(bytes32 _cType, address _safe) external;
}
