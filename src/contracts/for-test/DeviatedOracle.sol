// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {Math} from '@libraries/Math.sol';

// solhint-disable
contract DeviatedOracle is IBaseOracle {
  using Math for uint256;

  uint256 deviation; // WAD
  string public symbol;
  IOracleRelayer public oracleRelayer;

  constructor(address _oracleRelayer, uint256 _deviation) {
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    deviation = _deviation;
  }

  function getResultWithValidity() external view returns (uint256 _price, bool _validity) {
    _validity = true;
    _price = oracleRelayer.calcRedemptionPrice();
    _price = (_price / 1e9).wmul(deviation);
  }

  function read() external view returns (uint256 _price) {
    _price = oracleRelayer.calcRedemptionPrice();
    _price = (_price / 1e9).wmul(deviation);
  }
}
