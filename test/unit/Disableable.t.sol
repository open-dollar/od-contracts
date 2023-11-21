// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {DisableableForTest, IDisableable} from '@test/mocks/DisableableForTest.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  DisableableForTest disableable;

  function setUp() public virtual {
    vm.startPrank(deployer);

    disableable = new DisableableForTest();
    label(address(disableable), 'Disableable');

    disableable.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    stdstore.target(address(disableable)).sig(IDisableable.contractEnabled.selector).checked_write(_contractEnabled);
  }
}

contract Unit_Disableable_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    disableable = new DisableableForTest();
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(disableable.contractEnabled(), true);
  }
}

contract Unit_Disableable_DisableContract is Base {
  event DisableContract();
  event OnContractDisable();

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    disableable.disableContract();
  }

  function test_Revert_ContractIsDisabled() public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    disableable.disableContract();
  }

  function test_Set_ContractEnabled() public happyPath {
    disableable.disableContract();

    assertEq(disableable.contractEnabled(), false);
  }

  function test_Emit_OnContractDisable() public happyPath {
    vm.expectEmit();
    emit OnContractDisable();

    disableable.disableContract();
  }

  function test_Emit_DisableContract() public happyPath {
    vm.expectEmit();
    emit DisableContract();

    disableable.disableContract();
  }
}

contract Unit_Disableable_WhenEnabled is Base {
  function test_Revert_ContractIsDisabled() public {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    disableable.whenEnabledModifier();
  }

  function testFail_WhenEnabled() public {
    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    disableable.whenEnabledModifier();
  }
}

contract Unit_Disableable_WhenDisabled is Base {
  modifier happyPath() {
    _mockContractEnabled(false);
    _;
  }

  function test_Revert_ContractIsEnabled() public {
    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    disableable.whenDisabledModifier();
  }

  function testFail_WhenDisabled() public happyPath {
    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    disableable.whenDisabledModifier();
  }
}
