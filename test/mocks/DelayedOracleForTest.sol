// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

// solhint-disable
contract DelayedOracleForTest is IBaseOracle, IDelayedOracle {
  uint256 price;
  bool validity = true;
  bool throwsError;
  string public symbol;
  IBaseOracle public priceSource;

  constructor(uint256 _price, address _priceSource) {
    price = _price;
    if (_priceSource != address(0)) {
      priceSource = IBaseOracle(_priceSource);
    } else {
      priceSource = IBaseOracle(address(this));
    }
  }

  function getResultWithValidity() external view returns (uint256 _price, bool _validity) {
    _checkThrowsError();
    _price = price;
    _validity = validity;
  }

  function read() external view returns (uint256 _value) {
    return price;
  }

  // --- ForTest methods ---

  function setPriceAndValidity(uint256 _price, bool _validity) public virtual {
    price = _price;
    validity = _validity;
  }

  function setPriceSource(address _priceSource) public virtual {
    priceSource = IBaseOracle(_priceSource);
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
