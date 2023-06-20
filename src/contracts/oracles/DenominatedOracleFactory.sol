// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDenominatedOracleFactory} from '@interfaces/oracles/IDenominatedOracleFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract DenominatedOracleFactory is Authorizable, IDenominatedOracleFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---
  EnumerableSet.AddressSet internal _denominatedOracles;

  // --- Init ---
  constructor() Authorizable(msg.sender) {}

  // --- Methods ---
  function deployDenominatedOracle(
    IBaseOracle _priceSource,
    IBaseOracle _denominationPriceSource,
    bool _inverted
  ) external isAuthorized returns (address _denominatedOracle) {
    _denominatedOracle = address(new DenominatedOracle(_priceSource, _denominationPriceSource, _inverted));
    _denominatedOracles.add(_denominatedOracle);
    emit NewDenominatedOracle(_denominatedOracle, _priceSource, _denominationPriceSource, _inverted);
  }

  // --- Views ---
  function denominatedOraclesList() external view returns (address[] memory _denominatedOraclesList) {
    return _denominatedOracles.values();
  }
}
