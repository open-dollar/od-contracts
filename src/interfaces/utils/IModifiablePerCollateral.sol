// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';

interface IModifiablePerCollateral is IModifiable {
  // --- Admin ---
  function modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) external;
}
