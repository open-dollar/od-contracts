// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {BytesDecoder} from '@test/utils/BytesDecoder.sol';

abstract contract ActionBaseTest is Test, BytesDecoder {
  address public constant alice = address(0x01);
  ODProxy public proxy;
}
