// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableable} from '@interfaces/utils/IDisableable.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

abstract contract Disableable is IDisableable, Authorizable {
  // --- Data ---
  bool public contractEnabled = true;

  // --- External methods ---
  function disableContract() external isAuthorized whenEnabled {
    contractEnabled = false;
    _onContractDisable();
    emit DisableContract();
  }

  // --- Internal virtual methods ---

  /// @dev Method is instantiated, if not overriden it will just return
  function _onContractDisable() internal virtual {}

  function _isEnabled() internal view virtual returns (bool _enabled) {
    return contractEnabled;
  }

  // --- Modifiers ---
  modifier whenEnabled() {
    if (!_isEnabled()) revert ContractIsDisabled();
    _;
  }

  modifier whenDisabled() {
    if (_isEnabled()) revert ContractIsEnabled();
    _;
  }
}
