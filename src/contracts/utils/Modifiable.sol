// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

/**
 * @title Modifiable
 * @notice Allows inheriting contracts to modify parameters values
 * @dev    Requires inheriting contracts to override `_modifyParameters` virtual methods
 */
abstract contract Modifiable is IModifiable, Authorizable {
  // --- Constants ---

  /// @dev Used to emit a global parameter modification event
  bytes32 internal constant _GLOBAL_PARAM = bytes32(0);

  // --- External methods ---

  /// @inheritdoc IModifiable
  function modifyParameters(bytes32 _parameter, bytes memory _data) external isAuthorized {
    _modifyParameters(_parameter, _data);
    emit ModifyParameters(_parameter, _GLOBAL_PARAM, _data);
  }

  /// @inheritdoc IModifiable
  function modifyParameters(bytes32 _cType, bytes32 _parameter, bytes memory _data) external isAuthorized {
    _modifyParameters(_cType, _parameter, _data);
    emit ModifyParameters(_parameter, _cType, _data);
  }

  // --- Internal virtual methods ---

  /**
   * @notice Internal function to be overriden with custom logic to modify parameters
   * @dev    This function is set to revert if not overriden
   */
  // solhint-disable-next-line no-unused-vars
  function _modifyParameters(bytes32 _parameter, bytes memory _data) internal virtual {
    revert UnrecognizedParam();
  }

  /**
   * @notice Internal function to be overriden with custom logic to modify collateral parameters
   * @dev    This function is set to revert if not overriden
   */
  // solhint-disable-next-line no-unused-vars
  function _modifyParameters(bytes32 _cType, bytes32 _parameter, bytes memory _data) internal virtual {
    revert UnrecognizedParam();
  }
}
