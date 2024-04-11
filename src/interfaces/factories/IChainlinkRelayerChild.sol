// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IChainlinkRelayer} from '@interfaces/oracles/IChainlinkRelayer.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IChainlinkRelayerChild is IChainlinkRelayer, IFactoryChild {}
