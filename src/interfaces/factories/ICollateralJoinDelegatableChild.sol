// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralJoinChild} from '@interfaces/factories/ICollateralJoinChild.sol';

interface ICollateralJoinDelegatableChild is ICollateralJoinChild {
  // --- Registry ---

  /// @notice Address to whom the votes are delegated
  function delegatee() external view returns (address _delegatee);
}
