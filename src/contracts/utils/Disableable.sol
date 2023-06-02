// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

abstract contract Disableable is IDisableable, Authorizable {
  // --- Data ---
  uint256 public contractEnabled = 1;

  // --- External methods ---
  function disableContract() external isAuthorized whenEnabled {
    contractEnabled = 0;
    _onContractDisable();
    emit DisableContract();
  }

  // --- Internal virtual methods ---

  /// @dev Method is instantiated, if not overriden it will just return
  function _onContractDisable() internal virtual {}

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
