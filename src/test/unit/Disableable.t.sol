// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {DisableableForTest, IDisableable} from '@contracts/for-test/DisableableForTest.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');

  DisableableForTest disableable;

  function setUp() public virtual {
    vm.prank(deployer);
    disableable = new DisableableForTest();
    label(address(disableable), 'Disableable');
  }

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(disableable)).sig(IDisableable.contractEnabled.selector).checked_write(_contractEnabled);
  }
}

contract Unit_Disableable_Constructor is Base {
  function test_Set_ContractEnabled() public {
    assertEq(disableable.contractEnabled(), 1);
  }
}

contract Unit_Disableable_DisableContract is Base {
  event DisableContract();

  function test_Set_ContractEnabled() public {
    vm.prank(deployer);
    disableable.disableContract();

    assertEq(disableable.contractEnabled(), 0);
  }

  function test_Emit_DisableContract() public {
    vm.prank(deployer);
    expectEmitNoIndex();
    emit DisableContract();

    disableable.disableContract();
  }
}

contract Unit_Disableable_WhenEnabled is Base {
  function test_Revert_ContractIsDisabled() public {
    vm.prank(deployer);
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    disableable.whenEnabledModifier();
  }

  function testFail_WhenEnabled() public {
    vm.prank(deployer);
    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    disableable.whenEnabledModifier();
  }
}

contract Unit_Disableable_WhenDisabled is Base {
  modifier happyPath() {
    vm.prank(deployer);
    _mockContractEnabled(0);
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
