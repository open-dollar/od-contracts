// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

library Assertions {
  error NotGreaterThan(uint256 _x, uint256 _y);
  error NotLesserThan(uint256 _x, uint256 _y);
  error NotGreaterOrEqualThan(uint256 _x, uint256 _y);
  error NotLesserOrEqualThan(uint256 _x, uint256 _y);
  error NullAddress();

  // --- Assertions ---

  function assertGt(uint256 _x, uint256 _y) internal pure returns (uint256 __x) {
    if (_x <= _y) revert NotGreaterThan(_x, _y);
    return _x;
  }

  function assertGtEq(uint256 _x, uint256 _y) internal pure returns (uint256 __x) {
    if (_x < _y) revert NotGreaterOrEqualThan(_x, _y);
    return _x;
  }

  function assertLt(uint256 _x, uint256 _y) internal pure returns (uint256 __x) {
    if (_x >= _y) revert NotLesserThan(_x, _y);
    return _x;
  }

  function assertLtEq(uint256 _x, uint256 _y) internal pure returns (uint256 __x) {
    if (_x > _y) revert NotLesserOrEqualThan(_x, _y);
    return _x;
  }

  function assertNonNull(address _address) internal pure returns (address __address) {
    if (_address == address(0)) revert NullAddress();
    return _address;
  }
}
