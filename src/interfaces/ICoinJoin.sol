// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ICoinJoin {
  function coinName() external view returns (bytes32 _name);
  function systemCoin() external view returns (address _systemCoin);
  function join(address _account, uint256 _wad) external;
}
