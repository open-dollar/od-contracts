// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IToken {
  function mint(address _account, uint256 _amount) external;
  function approve(address _account, uint256 _amount) external returns (bool _success);
  function balanceOf(address _account) external view returns (uint256 _balance);
  function move(address _source, address _destination, uint256 _amount) external;
  function push(address _guy, uint256 _wad) external;
  function burn(address _account, uint256 _amount) external;
  function burn(uint256 _amount) external;
}
