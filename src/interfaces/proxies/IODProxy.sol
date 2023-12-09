// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// Open Dollar
// Version 1.5.8

interface IODProxy {
  function getLastExecution() external view returns (uint256 lastExecution);
}
