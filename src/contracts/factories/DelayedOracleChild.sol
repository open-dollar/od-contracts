// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDelayedOracleChild} from '@interfaces/factories/IDelayedOracleChild.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {DelayedOracle} from '@contracts/oracles/DelayedOracle.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  DelayedOracleChild
 * @notice This contract inherits all the functionality of `DelayedOracle.sol` to be factory deployed
 */
contract DelayedOracleChild is DelayedOracle, FactoryChild, IDelayedOracleChild {
  // --- Init ---
  constructor(IBaseOracle _priceSource, uint256 _updateDelay) DelayedOracle(_priceSource, _updateDelay) {}
}
