// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDenominatedOracleChild} from '@interfaces/factories/IDenominatedOracleChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  DenominatedOracleChild
 * @notice This contract inherits all the functionality of `DenominatedOracle.sol` to be factory deployed
 */
contract DenominatedOracleChild is DenominatedOracle, FactoryChild, IDenominatedOracleChild {
  // --- Init ---
  constructor(
    IBaseOracle _priceSource,
    IBaseOracle _denominationPriceSource,
    bool _inverted
  ) DenominatedOracle(_priceSource, _denominationPriceSource, _inverted) {}
}
