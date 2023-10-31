// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IDisableableChild} from '@interfaces/factories/IDisableableChild.sol';

import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  DisableableChild
 * @notice This abstract contract is used to disable Disableable children contracts through a parent factory
 */
abstract contract DisableableChild is Disableable, FactoryChild, IDisableableChild {
  // --- Overrides ---

  /**
   * @dev    Method override to check for contract enablement also in the parent factory
   * @return _enabled Whether the contract and the factory are enabled or not
   * @inheritdoc Disableable
   */
  function _isEnabled() internal view virtual override returns (bool _enabled) {
    return super._isEnabled() && IDisableable(factory).contractEnabled();
  }

  /**
   * @dev    Method override to allow disabling contract only through the parent factory
   * @inheritdoc Disableable
   */
  function _onContractDisable() internal virtual override onlyFactory {
    super._onContractDisable();
  }
}
