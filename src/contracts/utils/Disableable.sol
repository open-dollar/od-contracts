// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableable} from '@interfaces/utils/IDisableable.sol';

abstract contract Disableable is IDisableable {
  uint256 public contractEnabled = 1;

  function _disableContract() internal {
    contractEnabled = 0;
    emit DisableContract();
  }

  modifier whenEnabled() {
    if (contractEnabled == 0) revert ContractIsDisabled();
    _;
  }

  modifier whenDisabled() {
    if (contractEnabled == 1) revert ContractIsEnabled();
    _;
  }
}
