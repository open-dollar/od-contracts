// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Modifiable, IModifiable} from '@contracts/utils/Modifiable.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

contract ModifiableForTest is Modifiable {
  constructor() Modifiable() Authorizable(msg.sender) {}

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {}
}
