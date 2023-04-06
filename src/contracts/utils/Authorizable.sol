// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/IAuthorizable.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

abstract contract Authorizable is IAuthorizable {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private _authorizedAccounts;

  // --- Views ---

  /**
   * @notice Checks whether an account is authorized
   * @return _isAuthorized Whether the account is authorized (1) or not (0)
   * @dev This method allows backward compatibility with the old `authorizedAccounts` mapping
   */
  function authorizedAccounts(address _account) external view returns (uint256 _isAuthorized) {
    if (_authorizedAccounts.contains(_account)) return 1;
  }

  /**
   * @notice Getter for the authorized accounts
   * @return _accounts Array of authorized accounts
   */
  function authorizedAccounts() external view returns (address[] memory _accounts) {
    return _authorizedAccounts.values();
  }

  // --- Methods ---

  /**
   * @notice Add auth to an account
   * @param _account Account to add auth to
   */
  function addAuthorization(address _account) external virtual isAuthorized {
    _addAuthorization(_account);
  }

  /**
   * @notice Remove auth from an account
   * @param _account Account to remove auth from
   */
  function removeAuthorization(address _account) external virtual isAuthorized {
    _removeAuthorization(_account);
  }

  // --- Internal methods ---

  function _addAuthorization(address _account) internal {
    if (_authorizedAccounts.add(_account)) {
      emit AddAuthorization(_account);
    } else {
      revert AlreadyAuthorized();
    }
  }

  function _removeAuthorization(address _account) internal {
    if (_authorizedAccounts.remove(_account)) {
      emit RemoveAuthorization(_account);
    } else {
      revert NotAuthorized();
    }
  }

  // --- Modifiers ---

  /**
   * @notice Checks whether msg.sender can call an authed function
   */
  modifier isAuthorized() {
    if (!_authorizedAccounts.contains(msg.sender)) revert Unauthorized();
    _;
  }
}
