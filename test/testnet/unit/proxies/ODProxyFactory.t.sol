// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ODProxyFactory} from '@contracts/proxies/ODProxyFactory.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import 'forge-std/console.sol';

contract ODProxyFactoryTest is Test {
  error zeroLength();

  event ProxyCreated(address indexed owner, address indexed proxy);

  ODProxyFactory factory;
  address public constant alice = address(0x01);
  address public constant bob = address(0x02);

  function setUp() public {
    factory = new ODProxyFactory();
  }

  function testCreateProxy() public {
    address expectedProxy = factory.computeProxyAddress(bob);
    vm.expectEmit(true, true, true, true);
    emit ProxyCreated(bob, expectedProxy);
    address proxy = factory.createProxy(bob);
    assertEq(ODProxy(proxy).OWNER(), bob);
  }

  function testCreateProxies() public {
    address[] memory owners = new address[](2);
    owners[0] = alice;
    owners[1] = bob;
    address[] memory proxies = factory.createProxies(owners);

    // test precomputed proxy addresses
    assertEq(ODProxy(factory.computeProxyAddress(alice)).OWNER(), alice);
    assertEq(ODProxy(factory.computeProxyAddress(bob)).OWNER(), bob);

    // test deployed proxy addresses
    assertEq(ODProxy(proxies[0]).OWNER(), alice);
    assertEq(ODProxy(proxies[1]).OWNER(), bob);
  }

  function testCreateProxiesZeroLength() public {
    address[] memory owners = new address[](0);
    vm.expectRevert(zeroLength.selector);
    factory.createProxies(owners);
  }

  function testComputeProxyAddress() public {
    bytes memory bytecode = type(ODProxy).creationCode;
    bytecode = abi.encodePacked(bytecode, abi.encode(bob));

    bytes32 hash =
      keccak256(abi.encodePacked(bytes1(0xff), address(factory), keccak256(abi.encodePacked(bob)), keccak256(bytecode)));

    address proxyAddress = address(uint160(uint256(hash)));
    assertEq(factory.computeProxyAddress(bob), proxyAddress);

    // deploy proxy
    factory.createProxy(bob);
    assertEq(factory.computeProxyAddress(bob), proxyAddress);
  }
}
