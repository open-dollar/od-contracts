// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ModifiableForTestA, ModifiableForTestB, IModifiable} from '@test/mocks/ModifiableForTest.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ModifiableForTestA modifiable;

  function setUp() public virtual {
    vm.startPrank(deployer);

    modifiable = new ModifiableForTestA();
    label(address(modifiable), 'Modifiable');

    modifiable.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }
}

contract Unit_Modifiable_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    modifiable = new ModifiableForTestA();
  }
}

contract Unit_Modifiable_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(deployer);

    modifiable = ModifiableForTestA(address(new ModifiableForTestB()));
    label(address(modifiable), 'Modifiable');

    modifiable.addAuthorization(authorizedAccount);

    vm.stopPrank();
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _param, bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    modifiable.modifyParameters(_param, _data);
  }

  function test_Revert_UnrecognizedParam(bytes32 _param, bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    modifiable.modifyParameters(_param, _data);
  }

  function test_Emit_ModifyParameters(bytes32 _param, bytes memory _data) public happyPath {
    vm.expectEmit();
    emit ModifyParameters(_param, bytes32(0), _data);

    modifiable.modifyParameters(_param, _data);
  }
}

contract Unit_Modifiable_ModifyParametersPerCollateral is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(deployer);

    modifiable = ModifiableForTestA(address(new ModifiableForTestB()));
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

  function test_Revert_UnrecognizedParam(
    bytes32 _cType,
    bytes32 _param,
    bytes memory _data
  ) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    modifiable.modifyParameters(_cType, _param, _data);
  }

  function test_Emit_ModifyParameters(
    bytes32 _cType,
    bytes32 _param,
    bytes memory _data
  ) public happyPath {
    vm.expectEmit();
    emit ModifyParameters(_param, _cType, _data);

    modifiable.modifyParameters(_cType, _param, _data);
  }
}
