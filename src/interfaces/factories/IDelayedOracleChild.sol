// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IDelayedOracleChild is IDelayedOracle, IFactoryChild {}
