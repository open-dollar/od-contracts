// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Math} from '@libraries/Math.sol';
import {DSTestPlus, stdStorage, StdStorage} from '@defi-wonderland/solidity-utils/test/DSTestPlus.sol';

contract OverflowChecker {
  using Math for uint256;

  function trySum(uint256[] calldata _numbers) external pure returns (uint256 _total) {
    for (uint256 _i = 0; _i < _numbers.length; ++_i) {
      _total += _numbers[_i];
    }
  }

  function notOverflowAdd(uint256[] memory _numbers) public view returns (bool _valid) {
    try OverflowChecker(address(this)).trySum(_numbers) {
      _valid = true;
    } catch {
      _valid = false;
    }
  }

  function notOverflowAdd(uint256 _a, uint256 _b, uint256 _c) public view returns (bool _valid) {
    uint256[] memory _numbers = new uint256[](3);
    _numbers[0] = _a;
    _numbers[1] = _b;
    _numbers[2] = _c;

    return notOverflowAdd(_numbers);
  }

  function notOverflowAdd(uint256 _a, uint256 _b) public pure returns (bool _valid) {
    _valid = _a <= type(uint256).max - _b;
  }

  function notOverflowAdd(int256 _a, int256 _b) public pure returns (bool _valid) {
    if (_a == 0 || _b == 0) {
      _valid = true;
    } else if ((_a > 0 && _b < 0) || (_a < 0 && _b > 0)) {
      _valid = true;
    } else {
      if (_a == type(int256).min || _b == type(int256).min) {
        _valid = false;
      } else {
        _valid = uint256(type(int256).max) - Math.absolute(_b) >= Math.absolute(_a);
      }
    }
  }

  // When the result is int256
  function notOverflowAdd(uint256 _a, int256 _b) public pure returns (bool _valid) {
    _valid = type(int256).max - _b >= int256(_a);
  }

  function notUnderflow(uint256 _a, uint256 _b) public pure returns (bool _valid) {
    _valid = _a >= _b;
  }

  // When the result is uint256
  function notUnderOrOverflowAdd(uint256 _a, int256 _b) public pure returns (bool _valid) {
    if (_b < 0) {
      if (_b == type(int256).min) {
        _valid = false;
      } else {
        _valid = notUnderflow(_a, uint256(-_b));
      }
    } else {
      _valid = notOverflowAdd(_a, uint256(_b));
    }
  }

  // When the result is uint256
  function notUnderOrOverflowSub(uint256 _a, int256 _b) public pure returns (bool _valid) {
    if (_b > 0) {
      _valid = notUnderflow(_a, uint256(-_b));
    } else {
      _valid = notOverflowAdd(_a, uint256(_b));
    }
  }

  function notOverflowMul(uint256 _a, uint256 _b) public pure returns (bool _valid) {
    if (_a == 0 || _b == 0) {
      _valid = true;
    } else {
      _valid = _a <= type(uint256).max / _b;
    }
  }

  function notOverflowMul(int256 _a, int256 _b) public pure returns (bool _valid) {
    if (_a == 0 || _b == 0) {
      _valid = true;
    } else if (_b == type(int256).min || _a == type(int256).min) {
      _valid = false;
    } else {
      _valid = int256(Math.absolute(_a)) <= type(int256).max / int256(Math.absolute(_b));
    }
  }

  // When the result is uint256
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

  function tryRPow(uint256 _a, uint256 _b) external pure returns (uint256 _total) {
    _total = _a.rpow(_b);
  }

  function notOverflowRPow(uint256 _a, uint256 _b) public view returns (bool _valid) {
    try OverflowChecker(address(this)).tryRPow(_a, _b) {
      _valid = true;
    } catch {
      _valid = false;
    }
  }

  function notOverflowInt256(uint256 _number) public pure returns (bool _valid) {
    _valid = _number < 2 ** 255;
  }
}

abstract contract HaiTest is DSTestPlus, OverflowChecker {
  modifier mockAsContract(address _address) {
    // Foundry fuzzer sometimes gives us the next deployment address
    // this results in very unexpected reverts as any contract deploy will revert
    // we check here to make sure it's not the next deployment address for the (pranked) msg.sender
    (, address _msgSender,) = vm.readCallers();
    address _nextDeploymentAddr = computeCreateAddress(address(_msgSender), vm.getNonce(_msgSender));

    vm.assume(_address != _nextDeploymentAddr);

    // It should not be a precompile
    vm.assume(uint160(_address) > 20);

    // It should not be a deployed contract
    vm.assume(_address.code.length == 0);

    // Give it bytecode to make it a contract
    vm.etch(_address, '0xF');
    _;
  }
}
