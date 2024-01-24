// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@testnet/utils/HaiTest.t.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

contract Base is HaiTest {
  ODProxy odProxy;

  address owner = address(0xdeadce11);
  address deployer = address(0xbeef);

  function setUp() public virtual {
    vm.prank(deployer);

    odProxy = new ODProxy(owner);
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
