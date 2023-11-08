// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IDenominatedOracleFactory} from '@interfaces/factories/IDenominatedOracleFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {DenominatedOracleChild} from '@contracts/factories/DenominatedOracleChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  DenominatedOracleFactory
 * @notice This contract is used to deploy DenominatedOracle contracts
 * @dev    The deployed contracts are DenominatedOracleChild instances
 */
contract DenominatedOracleFactory is Authorizable, IDenominatedOracleFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---

  /// @notice The enumerable set of deployed DenominatedOracle contracts
  EnumerableSet.AddressSet internal _denominatedOracles;

  // --- Init ---

  constructor() Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IDenominatedOracleFactory
  function deployDenominatedOracle(
    IBaseOracle _priceSource,
    IBaseOracle _denominationPriceSource,
    bool _inverted
  ) external isAuthorized returns (IBaseOracle _denominatedOracle) {
    _denominatedOracle = new DenominatedOracleChild(_priceSource, _denominationPriceSource, _inverted);
    _denominatedOracles.add(address(_denominatedOracle));
    emit NewDenominatedOracle(
      address(_denominatedOracle), address(_priceSource), address(_denominationPriceSource), _inverted
    );
  }

  // --- Views ---

  /// @inheritdoc IDenominatedOracleFactory
  function denominatedOraclesList() external view returns (address[] memory _denominatedOraclesList) {
    return _denominatedOracles.values();
  }
}
