// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

// solhint-disable
contract OracleForTest is IBaseOracle, IDelayedOracle {
  uint256 price;
  bool validity = true;
  bool throwsError;
  string public symbol;

  constructor(uint256 _price) {
    price = _price;
  }

  function getResultWithValidity() external view returns (uint256 _price, bool _validity) {
    _checkThrowsError();
    _price = price;
    _validity = validity;
  }

  function setPriceAndValidity(uint256 _price, bool _validity) public virtual {
    price = _price;
    validity = _validity;
  }

  function priceSource() external view returns (IBaseOracle) {
    _checkThrowsError();
    return IBaseOracle(address(this));
  }

  function read() external view returns (uint256 _value) {
    return price;
  }

  function setThrowsError(bool _throwError) public virtual {
    throwsError = _throwError;
  }

  function _checkThrowsError() internal view {
    if (throwsError) {
      revert();
    }
  }

  // --- IDelayedOracle ---

  function getNextResultWithValidity() external view returns (uint256 _result, bool _validity) {
    return (price, validity);
  }

  function lastUpdateTime() external view returns (uint256 _lastUpdateTime) {
    return block.timestamp;
  }

  function shouldUpdate() external pure returns (bool _ok) {
    return true;
  }

  function updateDelay() external pure returns (uint256 _updateDelay) {
    return 0;
  }

  function updateResult() external pure returns (bool _success) {
    return true;
  }
}
