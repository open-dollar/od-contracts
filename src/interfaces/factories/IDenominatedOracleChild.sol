// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IDenominatedOracle} from '@interfaces/oracles/IDenominatedOracle.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IDenominatedOracleChild is IDenominatedOracle, IFactoryChild {}
