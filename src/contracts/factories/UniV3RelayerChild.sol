// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IUniV3RelayerChild} from '@interfaces/factories/IUniV3RelayerChild.sol';

import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

import {FactoryChild} from '@contracts/factories/FactoryChild.sol';

/**
 * @title  UniV3RelayerChild
 * @notice This contract inherits all the functionality of UniV3Relayer to be factory deployed
 */
contract UniV3RelayerChild is UniV3Relayer, FactoryChild, IUniV3RelayerChild {
  // --- Init ---

  /**
   * @param  _baseToken Address of the base token to be quoted
   * @param  _quoteToken Address of the quote reference token
   * @param  _feeTier Fee tier used to identify the UniV3 pool
   * @param  _quotePeriod Length of the period used to calculate the TWAP quote
   */
  constructor(
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) UniV3Relayer(_baseToken, _quoteToken, _feeTier, _quotePeriod) {}
}
