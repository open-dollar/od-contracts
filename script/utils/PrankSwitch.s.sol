// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';

contract PrankSwitch is Script, Test {
  uint256 internal _deployerPk;
  address internal _deployer;

  /**
   * @notice can use `override` in setUp to change .env variable in inherited contract
   * by default _deployerPk is set to ARB_MAINNET_DEPLOYER_PK
   */
  function setUp() public virtual {
    _deployerPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    _deployer = vm.addr(_deployerPk);
  }

  modifier prankSwitch(address _account) {
    if (_deployer == _account) {
      vm.startBroadcast(_deployerPk);
      _;
      vm.stopBroadcast();
    } else {
      vm.startPrank(_account);
      _;
      vm.stopPrank();
    }
  }
}
