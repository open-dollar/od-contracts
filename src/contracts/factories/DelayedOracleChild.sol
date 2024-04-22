// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IDelayedOracleChild} from '@interfaces/factories/IDelayedOracleChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {DelayedOracle} from '@contracts/oracles/DelayedOracle.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  DelayedOracleChild
 * @notice This contract inherits all the functionality of DelayedOracle to be factory deployed
 */
contract DelayedOracleChild is DelayedOracle, FactoryChild, IDelayedOracleChild {
  // --- Init ---

  /**
   *
   * @param  _priceSource Address of the price source
   * @param  _updateDelay Amount of seconds to be applied between the price source and the delayed oracle feeds
   */
  constructor(IBaseOracle _priceSource, uint256 _updateDelay) DelayedOracle(_priceSource, _updateDelay) {}
}
