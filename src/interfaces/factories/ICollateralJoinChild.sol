// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';

interface ICollateralJoinChild is ICollateralJoin, IFactoryChild {}
