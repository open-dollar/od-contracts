// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';

import {IJob, IStabilityFeeTreasury} from '@interfaces/jobs/IJob.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface IOracleJob is IJob, IAuthorizable, IModifiable {
  // --- Errors ---
  error NotWorkable();
  error InvalidPrice();

  // --- Data ---
  function shouldWorkUpdateCollateralPrice() external view returns (bool _shouldWorkUpdateCollateralPrice);
  function shouldWorkUpdateRate() external view returns (bool _shouldWorkUpdateRate);

  // --- Registry ---
  function oracleRelayer() external view returns (IOracleRelayer _oracleRelayer);
  function pidRateSetter() external view returns (IPIDRateSetter _pidRateSetter);

  // --- Job ---
  function workUpdateCollateralPrice(bytes32 _cType) external;
  function workUpdateRate() external;
}
