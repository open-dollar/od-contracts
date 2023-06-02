// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IModifiable is IAuthorizable {
  // --- Events ---
  /// @dev Event topic 1 is always a parameter, topic 2 can be empty (global params)
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  // --- Errors ---
  error UnrecognizedParam();

  // --- Administration ---
  /**
   * @notice Set a new value for a global specific parameter
   * @param _parameter String identifier of the parameter to modify
   * @param _data Encoded data to modify the parameter
   */
  function modifyParameters(bytes32 _parameter, bytes memory _data) external;

  /**
   * @notice Set a new value for a collateral specific parameter
   * @param _cType String identifier of the collateral to modify
   * @param _parameter String identifier of the parameter to modify
   * @param _data Encoded data to modify the parameter
   */
  function modifyParameters(bytes32 _cType, bytes32 _parameter, bytes memory _data) external;
}
