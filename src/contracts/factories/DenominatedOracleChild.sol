// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IDenominatedOracleChild} from '@interfaces/factories/IDenominatedOracleChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {DenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  DenominatedOracleChild
 * @notice This contract inherits all the functionality of DenominatedOracle to be factory deployed
 */
contract DenominatedOracleChild is DenominatedOracle, FactoryChild, IDenominatedOracleChild {
  // --- Init ---

  /**
   * @param  _priceSource Address of the price source
   * @param  _denominationPriceSource Address of the denomination price source
   * @param  _inverted Boolean indicating if the denomination quote should be inverted
   */
  constructor(
    IBaseOracle _priceSource,
    IBaseOracle _denominationPriceSource,
    bool _inverted
  ) DenominatedOracle(_priceSource, _denominationPriceSource, _inverted) {}
}
