// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizableChild} from '@interfaces/factories/IAuthorizableChild.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  AuthorizableChild
 * @notice This abstract contract is used to handle Authorizable children contracts through a parent factory
 * @dev    To give permissions to all children contracts, add authorization on the parent factory
 * @dev    To give permissions to a specific child contract, add authorization on the child contract
 */
abstract contract AuthorizableChild is Authorizable, FactoryChild, IAuthorizableChild {
  // --- Overrides ---

  /**
   * @dev    Method override to check for authorization also in the parent factory
   * @param  _account Account to check authorization for
   * @return _authorized Whether the account is authorized either in contract or in factory
   * @inheritdoc Authorizable
   */
  function _isAuthorized(address _account) internal view virtual override returns (bool _authorized) {
    return super._isAuthorized(_account) || IAuthorizable(factory).authorizedAccounts(_account);
  }
}
