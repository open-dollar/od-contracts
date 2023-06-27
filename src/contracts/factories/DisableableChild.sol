// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableableChild} from '@interfaces/factories/IDisableableChild.sol';

import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

abstract contract DisableableChild is Disableable, FactoryChild, IDisableableChild {
  function _isEnabled() internal view virtual override returns (bool _enabled) {
    return super._isEnabled() && IDisableable(factory).contractEnabled() == 1;
  }

  // NOTE: avoids a contract from being directly disabled
  function _onContractDisable() internal virtual override onlyFactory {
    super._onContractDisable();
  }
}
