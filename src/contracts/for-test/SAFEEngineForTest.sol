// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

contract SAFEEngineForTest {
  mapping(address => uint256) public coinBalance;
  mapping(address => uint256) public debtBalance;

  function mockCoinBalance(address _account, uint256 _balance) external {
    coinBalance[_account] = _balance;
  }

  function mockDebtBalance(address _account, uint256 _balance) external {
    debtBalance[_account] = _balance;
  }

  function settleDebt(uint256 _rad) external {
    debtBalance[msg.sender] -= _rad;
    coinBalance[msg.sender] -= _rad;
  }

  /// @dev Adds fallback to be able to mock any call without implementing it
  fallback() external {}
}
