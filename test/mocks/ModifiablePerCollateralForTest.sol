// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ModifiablePerCollateral, IModifiablePerCollateral} from '@contracts/utils/ModifiablePerCollateral.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

contract ModifiablePerCollateralForTest is ModifiablePerCollateral {
  constructor() Authorizable(msg.sender) {}

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {}

  function modifyParameters(bytes32 _param, bytes memory _data) external override {}

  function _initializeCollateralType(bytes32 _cType, bytes memory _collateralData) internal virtual override {}
}
