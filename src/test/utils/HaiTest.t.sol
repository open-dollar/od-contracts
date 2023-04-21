// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {DSTestPlus, stdStorage, StdStorage} from '@defi-wonderland/solidity-utils/test/DSTestPlus.sol';

contract OverflowChecker {
  function trySum(uint256[] calldata _numbers) external pure returns (uint256 _total) {
    for (uint256 i = 0; i < _numbers.length; i++) {
      _total += _numbers[i];
    }
  }

  function notOverflow(uint256[] memory _numbers) public view returns (bool _valid) {
    try OverflowChecker(address(this)).trySum(_numbers) {
      _valid = true;
    } catch {
      _valid = false;
    }
  }

  function notOverflow(uint256 _a, uint256 _b) public pure returns (bool _valid) {
    _valid = _a < type(uint256).max - _b;
  }

  function notOverflow(uint256 _a, uint256 _b, uint256 _c) public view returns (bool _valid) {
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

  function notOverflowWhenInt256(uint256 _number) public pure returns (bool _valid) {
    _valid = _number < 2 ** 255;
  }

  function notUnderflow(uint256 _a, uint256 _b) public pure returns (bool _valid) {
    _valid = _a >= _b;
  }

  function notUnderOrOverflowAdd(uint256 _a, int256 _b) public pure returns (bool _valid) {
    if (_b < 0) {
      if (_b == type(int256).min) {
        _valid = false;
      } else {
        _valid = notUnderflow(_a, uint256(-_b));
      }
    } else {
      _valid = notOverflow(_a, uint256(_b));
    }
  }

  function notUnderOrOverflowSub(uint256 _a, int256 _b) public pure returns (bool _valid) {
    if (_b > 0) {
      _valid = notUnderflow(_a, uint256(-_b));
    } else {
      _valid = notOverflow(_a, uint256(_b));
    }
  }

  function notOverflowMul(uint256 _a, uint256 _b) public pure returns (bool _valid) {
    if (_b == 0) {
      _valid = true;
    } else {
      _valid = _a <= type(uint256).max / _b;
    }
  }

  function notUnderOrOverflowMul(uint256 _a, int256 _b) public pure returns (bool _valid) {
    if (int256(_a) < 0) {
      _valid = false;
    } else if (_b == 0) {
      _valid = true;
    } else if (_b < 0) {
      if (_b == type(int256).min) {
        _valid = false;
      } else {
        _valid = _a <= uint256(type(int256).max) / uint256(-_b);
      }
    } else {
      _valid = _a <= uint256(type(int256).max) / uint256(_b);
    }
  }
}

abstract contract HaiTest is DSTestPlus, OverflowChecker {}
