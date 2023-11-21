// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IDelayedOracleFactory} from '@interfaces/factories/IDelayedOracleFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

import {DelayedOracleChild} from '@contracts/factories/DelayedOracleChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  DelayedOracleFactory
 * @notice This contract is used to deploy DelayedOracle contracts
 * @dev    The deployed contracts are DelayedOracleChild instances
 */
contract DelayedOracleFactory is Authorizable, IDelayedOracleFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice The enumerable set of deployed DelayedOracle contracts
  EnumerableSet.AddressSet internal _delayedOracles;

  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IDelayedOracleFactory
  function deployDelayedOracle(
    IBaseOracle _priceSource,
    uint256 _updateDelay
  ) external isAuthorized returns (IDelayedOracle _delayedOracle) {
    _delayedOracle = new DelayedOracleChild(_priceSource, _updateDelay);
    _delayedOracles.add(address(_delayedOracle));
    emit NewDelayedOracle(address(_delayedOracle), address(_priceSource), _updateDelay);
  }

  // --- Views ---

  /// @inheritdoc IDelayedOracleFactory
  function delayedOraclesList() external view returns (address[] memory _delayedOraclesList) {
    return _delayedOracles.values();
  }
}
