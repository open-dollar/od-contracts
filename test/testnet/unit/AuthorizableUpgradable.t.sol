// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AuthorizableUpgradableForTest, IAuthorizable } from '@testnet/mocks/AuthorizableUpgradableForTest.sol';
import {ODTest} from '@testnet/utils/ODTest.t.sol';

abstract contract Base is ODTest {
  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');

  AuthorizableUpgradableForTest authorizable;

  function setUp() public virtual {
    vm.startPrank(deployer);

    authorizable = new AuthorizableUpgradableForTest();
    authorizable.init(deployer);

    vm.stopPrank();
  }
}

contract Unit_AuthorizableUpgradable is Base {
  event AddAuthorization(address _account);
  event RemoveAuthorization(address _account);

  function test_Emit_AddAuthorization() public {
    vm.startPrank(deployer);
    address _account = newAddress();
    vm.expectEmit();
    emit AddAuthorization(_account);
    authorizable.addAuthorization(_account);
  }

  function test_Return_IsAuthorized() public {
    vm.startPrank(deployer);
    assertEq(authorizable.authorizedAccounts(deployer), true);
  }

  function test_Return_Accounts() public {
    vm.startPrank(deployer);
    address[] memory _authorizedAccounts = new address[](3);
    address account1 = deployer;
    address account2 = newAddress();
    address account3 = newAddress();

    _authorizedAccounts[0] = account1;
    _authorizedAccounts[1] = account2;
    _authorizedAccounts[2] = account3;

    authorizable.addAuthorization(account2);
    authorizable.addAuthorization(account3);

    assertEq(authorizable.authorizedAccounts(), _authorizedAccounts);
  }

  function test_Revert_AlreadyAuthorized() public {
    vm.startPrank(deployer);
    vm.expectRevert(IAuthorizable.AlreadyAuthorized.selector);
    authorizable.addAuthorization(deployer);
  }

  function test_Revert_NotAuthorized() public {
    vm.startPrank(address(0x11));
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    authorizable.removeAuthorization(address(0x11));
  }

  function test_Emit_RemoveAuthorization() public {
    vm.startPrank(deployer);
    vm.expectEmit();
    emit RemoveAuthorization(deployer);

    authorizable.removeAuthorization(deployer);
  }

  function test_Remove_Authorization() public {
    vm.startPrank(deployer);
    vm.expectRevert(IAuthorizable.NotAuthorized.selector);
    authorizable.removeAuthorization(address(0x21));

  }

}
