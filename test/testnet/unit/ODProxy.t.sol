// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@testnet/utils/HaiTest.t.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {SAFEEngineForTest, ISAFEEngine} from '@testnet/mocks/SAFEEngineForTest.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';

import {ITaxCollector} from '@interfaces/ITaxCollector.sol';

contract Base is HaiTest {
  ODProxy odProxy;
  ODSafeManager odSafeManager;
  ITaxCollector taxCollector;
  IVault721 vault721;
  ISAFEEngine safeEngine;

  address owner = address(0xdeadce11);
  address deployer = address(0xbeef);

  ISAFEEngine.SAFEEngineParams safeEngineParams =
    ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});

  function setUp() public virtual {
    vm.prank(deployer);

    safeEngine = new SAFEEngineForTest(safeEngineParams);
    vault721 = IVault721(address(mockContract('vault721')));
    taxCollector = ITaxCollector(address(mockContract('taxCollector')));
    odProxy = new ODProxy(owner);
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.initializeManager.selector), abi.encode());
    odSafeManager = new ODSafeManager(address(safeEngine), address(vault721), address(taxCollector));
  }
}

contract DummyLibraryForTest {
  address OWNER;

  function testFunction(address testAddress) public view returns (address) {
    require(testAddress != address(0));
    return OWNER;
  }
}

contract Unit_ODProxy_Execute is Base {
  DummyLibraryForTest mockLib;

  function setUp() public override {
    Base.setUp();
    mockLib = new DummyLibraryForTest();
  }

  function test_Execute() public {
    bytes memory encodedCall = abi.encodeWithSignature('testFunction(address)', owner);

    vm.prank(owner);
    odProxy.execute(address(mockLib), encodedCall);
  }

  function testExecute_Revert_CallRevert() public {
    bytes memory encodedCall = abi.encodeWithSignature('testFunction(address)', address(0));
    bytes memory emptyBytes;
    vm.expectRevert(abi.encodeWithSelector(ODProxy.TargetCallFailed.selector, emptyBytes));
    vm.prank(owner);
    odProxy.execute(address(mockLib), encodedCall);
  }

  function testExecute_Revert_OnlyOwner() public {
    bytes memory encodedCall = abi.encodeWithSignature('testFunction(address)', address(0));
    bytes memory emptyBytes;
    vm.expectRevert(abi.encodeWithSelector(ODProxy.OnlyOwner.selector));

    odProxy.execute(address(mockLib), encodedCall);
  }
}
