// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableable} from './IDisableable.sol';
import {IAuthorizable} from './IAuthorizable.sol';

interface ICoinSavingsAccount is IDisableable, IAuthorizable {
  function deposit(uint256 _wad) external;
  function withdraw(uint256 _wad) external;
  function nextAccumulatedRate() external view returns (uint256 _ray);
}
