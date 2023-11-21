// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
  ModifiablePerCollateralForTest, IModifiablePerCollateral
} from '@test/mocks/ModifiablePerCollateralForTest.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ModifiablePerCollateralForTest modifiable;

  function setUp() public virtual {
    vm.startPrank(deployer);

    modifiable = new ModifiablePerCollateralForTest();
    label(address(modifiable), 'Modifiable');

    modifiable.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }
}

contract Unit_ModifiablePerCollateral_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    modifiable = new ModifiablePerCollateralForTest();
  }
}

contract Unit_Modifiable_ModifyParametersPerCollateral is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(deployer);

    modifiable = ModifiablePerCollateralForTest(address(new ModifiablePerCollateralForTest()));
    label(address(modifiable), 'Modifiable');

    modifiable.addAuthorization(authorizedAccount);

    vm.stopPrank();
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _cType, bytes32 _param, bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    modifiable.modifyParameters(_cType, _param, _data);
  }

  function test_Emit_ModifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) public happyPath {
    vm.expectEmit();
    emit ModifyParameters(_param, _cType, _data);

    modifiable.modifyParameters(_cType, _param, _data);
  }
}
