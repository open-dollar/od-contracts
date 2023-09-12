// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IWeth {
  function deposit() external payable;
  function withdraw(uint256 _amount) external;
}
