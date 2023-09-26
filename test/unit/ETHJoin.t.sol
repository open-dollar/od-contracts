// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ETHJoinForTest, IETHJoin} from '@test/mocks/ETHJoinForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Math} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  address randomAccount = label('randomAccount');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));

  ETHJoinForTest ethJoin;

  // ETHJoin storage
  bytes32 collateralType = 'collateralType';

  function setUp() public virtual {
    vm.startPrank(deployer);

    ethJoin = new ETHJoinForTest(address(mockSafeEngine), collateralType);
    label(address(ethJoin), 'ETHJoin');

    ethJoin.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    ethJoin.setContractEnabled(_contractEnabled);
  }
}

contract Unit_ETHJoin_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    ethJoin = new ETHJoinForTest(address(mockSafeEngine), collateralType);
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(ethJoin.contractEnabled(), true);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    vm.assume(_safeEngine != address(0));
    ethJoin = new ETHJoinForTest(_safeEngine, collateralType);

    assertEq(address(ethJoin.safeEngine()), _safeEngine);
  }

  function test_Set_CollateralType(bytes32 _cType) public happyPath {
    ethJoin = new ETHJoinForTest(address(mockSafeEngine), _cType);

    assertEq(ethJoin.collateralType(), _cType);
  }

  function test_Set_Decimals() public happyPath {
    assertEq(ethJoin.decimals(), 18);
  }

  function test_Revert_Null_SafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    ethJoin = new ETHJoinForTest(address(0), collateralType);
  }
}

contract Unit_ETHJoin_Join is Base {
  event Join(address _sender, address _account, uint256 _wad);

  modifier happyPath(uint256 _wad) {
    startHoax(user, type(uint256).max);

    _assumeHappyPath(_wad);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal pure {
    vm.assume(notOverflowInt256(_wad));
  }

  function test_Revert_ContractIsDisabled(address _account, uint256 _wad) public {
    startHoax(user, type(uint256).max);

    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    ethJoin.join{value: _wad}(_account);
  }

  function test_Revert_IntOverflow(address _account, uint256 _wad) public {
    startHoax(user, type(uint256).max);

    vm.assume(!notOverflowInt256(_wad));

    vm.expectRevert(Math.IntOverflow.selector);

    ethJoin.join{value: _wad}(_account);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(
    address _account,
    uint256 _wad
  ) public happyPath(_wad) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.modifyCollateralBalance,
        (collateralType, _account, int256(_wad))
      ),
      1
    );

    ethJoin.join{value: _wad}(_account);
  }

  function test_Emit_Join(address _account, uint256 _wad) public happyPath(_wad) {
    vm.expectEmit();
    emit Join(user, _account, _wad);

    ethJoin.join{value: _wad}(_account);
  }
}

contract Unit_ETHJoin_Exit is Base {
  event Exit(address _sender, address _account, uint256 _wad);

  modifier happyPath(uint256 _wad) {
    vm.startPrank(user);
    deal(address(ethJoin), type(uint256).max);

    _assumeHappyPath(_wad);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal pure {
    vm.assume(notOverflowInt256(_wad));
  }

  function test_Revert_IntOverflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowInt256(_wad));

    vm.expectRevert(Math.IntOverflow.selector);

    ethJoin.exit(_account, _wad);
  }

  function test_Revert_FailedTransfer(address _account, uint256 _wad) public {
    vm.assume(int256(_wad) > 0);

    vm.expectRevert(IETHJoin.ETHJoin_FailedTransfer.selector);

    ethJoin.exit(_account, _wad);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(uint256 _wad) public happyPath(_wad) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, user, -int256(_wad))),
      1
    );

    ethJoin.exit(randomAccount, _wad);
  }

  function test_Emit_Exit(uint256 _wad) public happyPath(_wad) {
    vm.expectEmit();
    emit Exit(user, randomAccount, _wad);

    ethJoin.exit(randomAccount, _wad);
  }

  function test_Call_Account_Transfer(uint256 _wad) public happyPath(_wad) {
    ethJoin.exit(randomAccount, _wad);

    assertEq(randomAccount.balance, _wad);
  }
}
