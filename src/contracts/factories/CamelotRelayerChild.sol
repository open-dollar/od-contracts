// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICamelotRelayerChild} from '@interfaces/factories/ICamelotRelayerChild.sol';

import {CamelotRelayer} from '@contracts/oracles/CamelotRelayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  CamelotRelayerChild
 * @notice This contract inherits all the functionality of `CamelotRelayer.sol` to be factory deployed
 */
contract CamelotRelayerChild is CamelotRelayer, FactoryChild, ICamelotRelayerChild {
  // --- Init ---
  constructor(
    address _baseToken,
    address _quoteToken,
    uint32 _quotePeriod
  ) CamelotRelayer(_baseToken, _quoteToken, _quotePeriod) {}
}
