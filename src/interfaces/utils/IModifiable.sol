// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

bytes32 constant GLOBAL_PARAM = bytes32(0);

interface IModifiable {
  // --- Events ---
  // NOTE: Event topic 1 is always a parameter, topic 2 can be empty (global params)
  event ModifyParameters(bytes32 indexed _parameter, bytes32 indexed _collateralType, bytes _data);

  // --- Errors ---
  error UnrecognizedParam();

  // --- Admin ---
  function modifyParameters(bytes32 _param, bytes memory _data) external;
}
