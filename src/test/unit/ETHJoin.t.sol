// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ETHJoin} from '@contracts/utils/ETHJoin.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {Math} from '@libraries/Math.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  address randomAccount = label('randomAccount');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));

  ETHJoin ethJoin;

  // ETHJoin storage
  bytes32 collateralType = 'collateralType';

  function setUp() public virtual {
    vm.startPrank(deployer);

    ethJoin = new ETHJoin(address(mockSafeEngine), collateralType);
    label(address(ethJoin), 'ETHJoin');

    ethJoin.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(ethJoin)).sig(IDisableable.contractEnabled.selector).checked_write(_contractEnabled);
  }
}

contract Unit_ETHJoin_Constructor is Base {
  event AddAuthorization(address _account);

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  function test_Emit_AddAuthorization() public {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    ethJoin = new ETHJoin(address(mockSafeEngine), collateralType);
  }

  function test_Set_ContractEnabled() public {
    assertEq(ethJoin.contractEnabled(), 1);
  }

  function test_Set_SafeEngine(address _safeEngine) public {
    ethJoin = new ETHJoin(_safeEngine, collateralType);

    assertEq(address(ethJoin.safeEngine()), _safeEngine);
  }

  function test_Set_CollateralType(bytes32 _collateralType) public {
    ethJoin = new ETHJoin(address(mockSafeEngine), _collateralType);

    assertEq(ethJoin.collateralType(), _collateralType);
  }

  function test_Set_Decimals() public {
    assertEq(ethJoin.decimals(), 18);
  }
}

contract Unit_ETHJoin_DisableContract is Base {
  event DisableContract();

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    ethJoin.disableContract();
  }

  function test_Revert_ContractIsDisabled() public authorized {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    ethJoin.disableContract();
  }

  function test_Emit_DisableContract() public authorized {
    expectEmitNoIndex();
    emit DisableContract();

    ethJoin.disableContract();
  }
}

contract Unit_ETHJoin_Join is Base {
  event Join(address _sender, address _account, uint256 _wad);

  function setUp() public override {
    Base.setUp();

    startHoax(user, type(uint256).max);
  }

  modifier happyPath(uint256 _wad) {
    _assumeHappyPath(_wad);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal {
    vm.assume(notOverflowWhenInt256(_wad));
  }

  function test_Revert_ContractIsDisabled(address _account, uint256 _wad) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    ethJoin.join{value: _wad}(_account);
  }

  function test_Revert_Overflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowWhenInt256(_wad));

    vm.expectRevert(Math.IntOverflow.selector);

    ethJoin.join{value: _wad}(_account);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(address _account, uint256 _wad) public happyPath(_wad) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, _account, int256(_wad)))
    );

    ethJoin.join{value: _wad}(_account);
  }

  function test_Emit_Join(address _account, uint256 _wad) public happyPath(_wad) {
    expectEmitNoIndex();
    emit Join(user, _account, _wad);

    ethJoin.join{value: _wad}(_account);
  }
}

contract Unit_ETHJoin_Exit is Base {
  event Exit(address _sender, address _account, uint256 _wad);

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  modifier happyPath(uint256 _wad) {
    _assumeHappyPath(_wad);
    deal(address(ethJoin), type(uint256).max);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal {
    vm.assume(notOverflowWhenInt256(_wad));
  }

  function test_Revert_Overflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowWhenInt256(_wad));

    vm.expectRevert(Math.IntOverflow.selector);

    ethJoin.exit(_account, _wad);
  }

  function test_Revert_FailedTransfer(address _account, uint256 _wad) public {
    vm.assume(int256(_wad) > 0);

    vm.expectRevert('ETHJoin/failed-transfer');

    ethJoin.exit(_account, _wad);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(uint256 _wad) public happyPath(_wad) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, user, -int256(_wad)))
    );

    ethJoin.exit(randomAccount, _wad);
  }

  function test_Emit_Exit(uint256 _wad) public happyPath(_wad) {
    expectEmitNoIndex();
    emit Exit(user, randomAccount, _wad);

    ethJoin.exit(randomAccount, _wad);
  }

  function test_Call_Account_Transfer(uint256 _wad) public happyPath(_wad) {
    ethJoin.exit(randomAccount, _wad);

    assertEq(randomAccount.balance, _wad);
  }
}
