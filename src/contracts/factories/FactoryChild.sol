// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

abstract contract FactoryChild is IFactoryChild {
  // --- Registry ---
  address public factory;

  // --- Init ---
  constructor() {
    factory = msg.sender;
    if (factory.code.length == 0) revert NotFactoryDeployment();
  }

  modifier onlyFactory() {
    if (msg.sender != factory) revert CallerNotFactory();
    _;
  }
}
