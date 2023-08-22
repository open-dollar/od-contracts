// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IVault721 {
  function mint(address proxy, uint256 safeId) external;
  function initialize() external;
  function governor() external returns (address);
  function safeManager() external returns (address);
}
