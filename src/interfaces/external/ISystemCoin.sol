// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// TODO: replace with IERC20?
interface ISystemCoin {
  function balanceOf(address _account) external view returns (uint256 _balance);
  function approve(address _account, uint256 _amount) external returns (bool _success);
  function transfer(address _account, uint256 _amount) external returns (bool _success);
  function transferFrom(address, address, uint256) external returns (bool _success);
  function decimals() external view returns (uint256);
}
