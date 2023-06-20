// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDelayedOracleFactory} from '@interfaces/oracles/IDelayedOracleFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {DelayedOracle} from '@contracts/oracles/DelayedOracle.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract DelayedOracleFactory is Authorizable, IDelayedOracleFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---
  EnumerableSet.AddressSet internal _delayedOracles;

  // --- Init ---
  constructor() Authorizable(msg.sender) {}

  // --- Methods ---
  function deployDelayedOracle(
    IBaseOracle _priceSource,
    uint256 _updateDelay
  ) external isAuthorized returns (address _delayedOracle) {
    _delayedOracle = address(new DelayedOracle(_priceSource, _updateDelay));
    _delayedOracles.add(_delayedOracle);
    emit NewDelayedOracle(_delayedOracle, _priceSource, _updateDelay);
  }

  // --- Views ---
  function delayedOraclesList() external view returns (address[] memory _delayedOraclesList) {
    return _delayedOracles.values();
  }
}
