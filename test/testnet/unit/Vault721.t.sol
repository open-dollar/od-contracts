// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address owner = label('owner');

  Vault721 vault721;
  NFTRenderer renderer;
  ODSafeManager safeManager;
  TimelockController timelockController;

  function setUp() public virtual {
    vm.startPrank(deployer);

    vault721 = new Vault721();
    label(address(vault721), 'Vault721');

    renderer = NFTRenderer(mockContract('nftRenderer'));
    safeManager = ODSafeManager(mockContract('SafeManager'));
    timelockController = TimelockController(payable(mockContract('timeLockController')));

    vm.stopPrank();
  }
}

contract Unit_Vault721_Initialize is Base {
  modifier safeManagerPath() {
    vm.startPrank(address(safeManager));
    _;
  }

  modifier rendererPath() {
    vm.startPrank(address(renderer));
    _;
  }

  function testInitialize() public {
    vault721.initialize(address(timelockController));
  }

  function testInitSafeManager() public safeManagerPath {
    vault721.initializeManager();
  }

  function testInitNftRenderer() public safeManagerPath {
    vault721.initializeRenderer();
  }

  function testInitializeZeroFail() public {
    vm.expectRevert(IVault721.ZeroAddress.selector);
    vault721.initialize(address(0));
  }

  function testInitializeMultiInitFail() public {
    vault721.initialize(address(timelockController));
    vm.expectRevert(bytes('Initializable: contract is already initialized'));
    vault721.initialize(address(timelockController));
  }
}
