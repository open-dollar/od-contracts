// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';

import {IJob} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ILiquidationJob is IAuthorizable, IModifiable, IJob {
  // --- Data ---

  /// @notice Whether the liquidation job should be worked
  function shouldWork() external view returns (bool _shouldWork);

  // --- Registry ---

  /// @notice Address of the LiquidationEngine contract
  function liquidationEngine() external view returns (ILiquidationEngine _liquidationEngine);

  // --- Job ---

  /**
   * @notice Rewarded method to liquidate a SAFE
   * @param _cType Bytes32 representation of the collateral type
   * @param _safe Address of the SAFE to liquidate
   */
  function workLiquidation(bytes32 _cType, address _safe) external;
}
