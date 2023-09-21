// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';

interface IVault721 {
  function safeManager() external returns (IODSafeManager);
  function mint(address proxy, uint256 safeId) external;
  function initialize() external;
  function governor() external returns (address);
}
