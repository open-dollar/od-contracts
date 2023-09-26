// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Modifiable, IModifiable} from '@contracts/utils/Modifiable.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

contract ModifiableForTestA is Modifiable {
  constructor() Modifiable() Authorizable(msg.sender) {}
}

contract ModifiableForTestB is Modifiable {
  constructor() Modifiable() Authorizable(msg.sender) {}

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {}

  function _modifyParameters(
    bytes32 _cType,
    bytes32 _param,
    bytes memory _data
  ) internal override {}
}
