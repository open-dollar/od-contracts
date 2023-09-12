// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IOwnable {
  // --- Events ---
  event SetOwner(address _newOwner);

  // --- Errors ---
  error OnlyOwner();

  // --- Data ---
  function owner() external view returns (address _owner);

  // --- Admin ---
  function setOwner(address _newOwner) external;
}
