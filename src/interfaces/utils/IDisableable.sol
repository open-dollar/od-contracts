// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IDisableable {
  // --- Events ---
  event DisableContract();

  // --- Errors ---
  error ContractIsEnabled();
  error ContractIsDisabled();
  error NonDisableable();

  // --- Data ---
  function contractEnabled() external view returns (uint256 _contractEnabled);

  // --- Shutdown ---
  function disableContract() external;
}
