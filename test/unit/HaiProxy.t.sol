// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiProxy, IHaiProxy} from '@contracts/proxies/HaiProxy.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Address} from '@openzeppelin/utils/Address.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address owner = label('owner');

  HaiProxy proxy;

  function setUp() public virtual {
    vm.startPrank(deployer);

    proxy = new HaiProxy(owner);
    label(address(proxy), 'HaiProxy');

    vm.stopPrank();
  }
}

contract Unit_HaiProxy_Execute is Base {
  address target = label('target');

  modifier happyPath() {
    vm.startPrank(owner);
    _;
  }

  function test_Execute() public happyPath mockAsContract(target) {
    proxy.execute(target, bytes(''));
  }

  function test_Revert_TargetNoCode() public happyPath {
    vm.expectRevert(abi.encodeWithSelector(Address.AddressEmptyCode.selector, target));

    proxy.execute(target, bytes(''));

    // Sanity check
    assert(target.code.length == 0);
  }

  function test_Revert_TargetAddressZero() public happyPath {
    vm.expectRevert(IHaiProxy.TargetAddressRequired.selector);

    proxy.execute(address(0), bytes(''));
  }
}
