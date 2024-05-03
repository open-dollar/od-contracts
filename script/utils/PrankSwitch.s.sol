// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';

contract PrankSwitch is Script, Test {
  uint256 internal _deployerPk;
  address internal _deployer;

  function setUp() public virtual {
    _deployerPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    _deployer = vm.addr(_deployerPk);
  }

  modifier prankSwitch(address _caller, address _account) {
    bool _broadcast;
    if (_caller == _account) _broadcast = true;
    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_account);
    _;
    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}
