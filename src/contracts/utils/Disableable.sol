// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableable} from '@interfaces/utils/IDisableable.sol';

abstract contract Disableable is IDisableable {
  // --- Data ---
  uint256 public contractEnabled = 1;

  // --- Internal methods ---
  function _disableContract() internal {
    contractEnabled = 0;
    emit DisableContract();
  }

  // --- Modifiers ---
  modifier whenEnabled() {
    if (contractEnabled == 0) revert ContractIsDisabled();
    _;
  }

  modifier whenDisabled() {
    if (contractEnabled == 1) revert ContractIsEnabled();
    _;
  }
}
