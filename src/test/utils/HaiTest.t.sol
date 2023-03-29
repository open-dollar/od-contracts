// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {DSTestPlus} from '@defi-wonderland/solidity-utils/test/DSTestPlus.sol';

contract OverflowChecker {
  function trySum(uint256[] calldata _numbers) external returns (uint256 _total) {
    for (uint256 i = 0; i < _numbers.length; i++) {
      _total += _numbers[i];
    }
  }

  function notOverflow(uint256[] memory _numbers) public returns (bool _valid) {
    try OverflowChecker(address(this)).trySum(_numbers) {
      _valid = true;
    } catch {
      _valid = false;
    }
  }

  function notOverflow(uint256 _a, uint256 _b) public returns (bool _valid) {
    return _a < type(uint256).max - _b;
  }

  function notOverflow(uint256 _a, uint256 _b, uint256 _c) public returns (bool _valid) {
    uint256[] memory _numbers = new uint256[](3);
    _numbers[0] = _a;
    _numbers[1] = _b;
    _numbers[2] = _c;
    try OverflowChecker(address(this)).trySum(_numbers) {
      _valid = true;
    } catch {
      _valid = false;
    }
  }
}

abstract contract HaiTest is DSTestPlus, OverflowChecker {}
