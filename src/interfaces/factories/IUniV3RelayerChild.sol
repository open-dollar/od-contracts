// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IUniV3Relayer} from '@interfaces/oracles/IUniV3Relayer.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IUniV3RelayerChild is IUniV3Relayer, IFactoryChild {}
