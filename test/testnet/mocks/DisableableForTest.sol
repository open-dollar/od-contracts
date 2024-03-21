// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

contract DisableableForTest is Disableable {
  event OnContractDisable();

  constructor() Disableable() Authorizable(msg.sender) {}

  function _onContractDisable() internal override {
    emit OnContractDisable();
  }

  function whenEnabledModifier() external whenEnabled {}

  function whenDisabledModifier() external whenDisabled {}
}
