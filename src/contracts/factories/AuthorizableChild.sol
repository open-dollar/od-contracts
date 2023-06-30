// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizableChild} from '@interfaces/factories/IAuthorizableChild.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

abstract contract AuthorizableChild is Authorizable, FactoryChild, IAuthorizableChild {
  function _isAuthorized(address _account) internal view virtual override returns (bool _authorized) {
    return super._isAuthorized(_account) || IAuthorizable(factory).authorizedAccounts(_account);
  }
}
