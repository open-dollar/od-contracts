// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableable} from '@interfaces/utils/IDisableable.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface IDisableableChild is IDisableable, IFactoryChild {}
