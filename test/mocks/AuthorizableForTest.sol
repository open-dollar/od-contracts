// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';

contract AuthorizableForTest is Authorizable {
  error ModifierError();

  constructor(address _account) Authorizable(_account) {}

  function isAuthorizedModifier() external isAuthorized {}

  function modifierOrderA() external isAuthorized revertingModifier {}

  function modifierOrderB() external revertingModifier isAuthorized {}

  modifier revertingModifier() {
    revert ModifierError();
    _;
  }
}
