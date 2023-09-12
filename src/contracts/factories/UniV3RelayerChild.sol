// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IUniV3RelayerChild} from '@interfaces/factories/IUniV3RelayerChild.sol';

import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  UniV3RelayerChild
 * @notice This contract inherits all the functionality of `UniV3Relayer.sol` to be factory deployed
 */
contract UniV3RelayerChild is UniV3Relayer, FactoryChild, IUniV3RelayerChild {
  // --- Init ---
  constructor(
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) UniV3Relayer(_baseToken, _quoteToken, _feeTier, _quotePeriod) {}
}
