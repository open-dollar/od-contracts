// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

// solhint-disable
contract HardcodedOracle is IBaseOracle {
  uint256 /* WAD */ price;
  string public symbol;

  constructor(string memory _symbol, uint256 _price) {
    symbol = _symbol;
    price = _price;
  }

  function getResultWithValidity() external view returns (uint256 _price, bool _validity) {
    _price = price;
    _validity = true;
  }

  function read() external view returns (uint256 _value) {
    return price;
  }
}
