// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';

contract DisableableForTest is Disableable {
  constructor() Disableable() {}

  function disableContract() external {
    _disableContract();
  }

  function whenEnabledModifier() external whenEnabled {}

  function whenDisabledModifier() external whenDisabled {}
}
