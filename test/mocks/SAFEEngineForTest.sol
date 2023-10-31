// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {SAFEEngine, ISAFEEngine, EnumerableSet} from '@contracts/SAFEEngine.sol';

contract DummySAFEEngine {
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
  // solhint-disable-next-line payable-fallback
  fallback() external {}
}

contract SAFEEngineForTest is SAFEEngine {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(SAFEEngineParams memory _safeEngineParams) SAFEEngine(_safeEngineParams) {}

  function addToCollateralList(bytes32 _cType) external {
    _collateralList.add(_cType);
  }
}
