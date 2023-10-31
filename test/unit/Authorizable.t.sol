// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AuthorizableForTest, IAuthorizable} from '@test/mocks/AuthorizableForTest.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');

  AuthorizableForTest authorizable;

  function setUp() public virtual {
    vm.startPrank(deployer);

    authorizable = new AuthorizableForTest(authorizedAccount);
    label(address(authorizable), 'Authorizable');

    vm.stopPrank();
  }
}

contract Unit_Authorizable_Constructor is Base {
  event AddAuthorization(address _account);

  function test_Emit_AddAuthorization(address _account) public {
    vm.expectEmit();
    emit AddAuthorization(_account);

    authorizable = new AuthorizableForTest(_account);
  }
}

contract Unit_Authorizable_AuthorizedAccounts is Base {
  function test_Return_IsAuthorized(address _account) public {
    vm.assume(_account != authorizedAccount);

    assertEq(authorizable.authorizedAccounts(_account), false);

    assertEq(authorizable.authorizedAccounts(authorizedAccount), true);
  }

  function test_Return_Accounts() public {
    address[] memory _authorizedAccounts = new address[](100);
    _authorizedAccounts[0] = authorizedAccount;

    vm.startPrank(authorizedAccount);
    for (uint256 _i = 1; _i < 100; ++_i) {
      address _account = newAddress();
      authorizable.addAuthorization(_account);
      _authorizedAccounts[_i] = _account;
    }

    assertEq(authorizable.authorizedAccounts(), _authorizedAccounts);
  }
}

contract Unit_Authorizable_AddAuthorization is Base {
  event AddAuthorization(address _account);

  modifier happyPath(address _account) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_account);
    _;
  }

  function _assumeHappyPath(address _account) internal view {
    vm.assume(_account != authorizedAccount);
  }

  function test_Revert_Unauthorized(address _account) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    authorizable.addAuthorization(_account);
  }

  function test_Revert_AlreadyAuthorized() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IAuthorizable.AlreadyAuthorized.selector);

    authorizable.addAuthorization(authorizedAccount);
  }

  function test_Set_AuthorizedAccounts(address _account) public happyPath(_account) {
    authorizable.addAuthorization(_account);

    assertEq(authorizable.authorizedAccounts(_account), true);
  }

  function test_Emit_AddAuthorization(address _account) public happyPath(_account) {
    vm.expectEmit();
    emit AddAuthorization(_account);

    authorizable.addAuthorization(_account);
  }
}

contract Unit_Authorizable_RemoveAuthorization is Base {
  event RemoveAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(address _account) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    authorizable.removeAuthorization(_account);
  }

  function test_Revert_NotAuthorized(address _account) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_account != authorizedAccount);

    vm.expectRevert(IAuthorizable.NotAuthorized.selector);

    authorizable.removeAuthorization(_account);
  }

  function test_Set_AuthorizedAccounts() public happyPath {
    authorizable.removeAuthorization(authorizedAccount);

    assertEq(authorizable.authorizedAccounts(authorizedAccount), false);
  }

  function test_Emit_RemoveAuthorization() public happyPath {
    vm.expectEmit();
    emit RemoveAuthorization(authorizedAccount);

    authorizable.removeAuthorization(authorizedAccount);
  }
}

contract Unit_Authorizable_IsAuthorized is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    authorizable.isAuthorizedModifier();
  }

  function testFail_IsAuthorized() public happyPath {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    authorizable.isAuthorizedModifier();
  }

  function test_ModifierOrderA() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    authorizable.modifierOrderA();
  }

  function test_ModifierOrderB() public {
    vm.expectRevert(AuthorizableForTest.ModifierError.selector);

    authorizable.modifierOrderB();
  }
}
