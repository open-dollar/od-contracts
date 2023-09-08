// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IVault721 {
  function mint(address proxy, uint256 safeId) external;
  function initialize(address _safeEngine) external;
  function governor() external returns (address);
}
