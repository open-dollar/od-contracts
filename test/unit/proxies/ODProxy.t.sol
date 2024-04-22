// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

// create mock contract to test ODProxy
contract MockProxyTarget {
  error TestFail();

  function call() public pure returns (bool) {
    return true;
  }

  function payableCall() public payable returns (bool) {
    return true;
  }

  function callWithArgs(uint256 a, uint256 b) public pure returns (uint256) {
    return a + b;
  }

  function callWillFail() public pure returns (bool) {
    revert TestFail();
  }
}

contract ODProxyTest is Test {
  error TargetAddressRequired();
  error TargetCallFailed(bytes _response);
  error OnlyOwner();
  error TestFail();

  address public constant alice = address(0x01);
  address public constant bob = address(0x02);
  ODProxy proxy;

  // target contract to test proxy calls
  MockProxyTarget target = new MockProxyTarget();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function testOwner() public {
    assertEq(proxy.OWNER(), alice);
  }

  function testExecute() public {
    vm.startPrank(alice);
    bytes memory resp = proxy.execute(address(target), abi.encodeWithSignature('call()'));
    assertTrue(abi.decode(resp, (bool)));
  }

  function testExecuteWithArgs() public {
    vm.startPrank(alice);
    bytes memory resp = proxy.execute(address(target), abi.encodeWithSignature('callWithArgs(uint256,uint256)', 1, 2));
    assertEq(abi.decode(resp, (uint256)), 3);
  }

  function testExecuteWithNoTarget() public {
    vm.startPrank(alice);
    vm.expectRevert(TargetAddressRequired.selector);
    proxy.execute(address(0), abi.encodeWithSignature('call()'));
  }

  function testExecuteNonOwner() public {
    vm.startPrank(bob);
    vm.expectRevert(OnlyOwner.selector);
    proxy.execute(address(target), abi.encodeWithSignature('call()'));
  }

  function testExecuteWillFail() public {
    vm.startPrank(alice);
    vm.expectRevert();
    proxy.execute(address(target), abi.encodeWithSignature('callWillFail()'));
  }

  function testArbitraryExecute() public {
    vm.startPrank(alice);
    bytes memory resp = proxy.arbitraryExecute(address(target), abi.encodeWithSignature('call()'));
    assertTrue(abi.decode(resp, (bool)));
  }

  // function testArbitraryExecuteWithValue() public {
  //   vm.startPrank(alice);
  //   vm.deal(address(proxy), 1 ether);
  //   bytes memory resp = proxy.arbitraryExecute(address(target), abi.encodeWithSignature('payableCall()'), 1 ether);
  //   assertTrue(abi.decode(resp, (bool)));
  // }

  // function testArbitraryExecuteWithValueFail() public {
  //   vm.startPrank(alice);
  //   vm.expectRevert('Address: insufficient balance for call');
  //   proxy.arbitraryExecute(address(target), abi.encodeWithSignature('payableCall()'), 1 ether);
  // }

  function testArbitraryExecuteWithArgs() public {
    vm.startPrank(alice);
    bytes memory resp =
      proxy.arbitraryExecute(address(target), abi.encodeWithSignature('callWithArgs(uint256,uint256)', 1, 2));
    assertEq(abi.decode(resp, (uint256)), 3);
  }

  function testArbitraryExecuteWithNoTarget() public {
    vm.startPrank(alice);
    vm.expectRevert('Address: call to non-contract');
    proxy.arbitraryExecute(address(0), abi.encodeWithSignature('call()'));
  }

  function testArbitraryExecuteNonOwner() public {
    vm.startPrank(bob);
    vm.expectRevert(OnlyOwner.selector);
    proxy.arbitraryExecute(address(target), abi.encodeWithSignature('call()'));
  }

  function testArbitraryExecuteWillFail() public {
    vm.startPrank(alice);
    vm.expectRevert();
    proxy.arbitraryExecute(address(target), abi.encodeWithSignature('callWillFail()'));
  }
}
