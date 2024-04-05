// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AuthorizableUpgradeable, IAuthorizable} from '@contracts/utils/AuthorizableUpgradeable.sol';

contract AuthorizableUpgradableForTest is AuthorizableUpgradeable {
  error ModifierError();

  function init(address _deployer) public initializer {
    __authorizable_init(_deployer);
  }

  function isAuthorizedModifier() external isAuthorized {}

  function modifierOrderA() external isAuthorized revertingModifier {}

  function modifierOrderB() external revertingModifier isAuthorized {}

  modifier revertingModifier() {
    revert ModifierError();
    _;
  }
}
