// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IDisableable {
  // --- Events ---
  event DisableContract();

  // --- Data ---
  function contractEnabled() external view returns (uint256 _enabled);

  // --- Admin ---
  function disableContract() external;
}
