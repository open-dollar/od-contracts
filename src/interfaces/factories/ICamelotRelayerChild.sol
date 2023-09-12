// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICamelotRelayer} from '@interfaces/oracles/ICamelotRelayer.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface ICamelotRelayerChild is ICamelotRelayer, IFactoryChild {}
