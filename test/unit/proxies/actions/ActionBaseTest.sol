// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

abstract contract ActionBaseTest is Test {
  address public constant alice = address(0x01);
  ODProxy public proxy;
}
