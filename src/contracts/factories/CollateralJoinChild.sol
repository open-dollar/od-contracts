// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralJoinChild} from '@interfaces/factories/ICollateralJoinChild.sol';

import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';

import {DisableableChild, Disableable} from '@contracts/factories/DisableableChild.sol';

/**
 * @title  CollateralJoinChild
 * @notice This contract inherits all the functionality of `CollateralJoin.sol` to be factory deployed
 */
contract CollateralJoinChild is CollateralJoin, DisableableChild, ICollateralJoinChild {
  // --- Init ---
  constructor(
    address _safeEngine,
    bytes32 _cType,
    address _collateral
  ) CollateralJoin(_safeEngine, _cType, _collateral) {}

  function _isEnabled() internal view override(DisableableChild, Disableable) returns (bool _enabled) {
    return super._isEnabled();
  }

  function _onContractDisable() internal override(DisableableChild, Disableable) {
    super._onContractDisable();
  }
}
