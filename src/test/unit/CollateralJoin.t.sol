// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISystemCoin} from '@interfaces/external/ISystemCoin.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {Math} from '@libraries/Math.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  ISystemCoin mockCollateral = ISystemCoin(mockContract('Collateral'));

  CollateralJoin collateralJoin;

  // CollateralJoin storage
  bytes32 collateralType = 'collateralType';

  function setUp() public virtual {
    vm.startPrank(deployer);

    _mockDecimals(18);

    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));
    label(address(collateralJoin), 'CollateralJoin');

    collateralJoin.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockDecimals(uint256 _decimals) internal {
    vm.mockCall(address(mockCollateral), abi.encodeCall(mockCollateral.decimals, ()), abi.encode(_decimals));
  }

  function _mockTransfer(address _account, uint256 _amount, bool _success) internal {
    vm.mockCall(
      address(mockCollateral), abi.encodeCall(mockCollateral.transfer, (_account, _amount)), abi.encode(_success)
    );
  }

  function _mockTransferFrom(address _accountFrom, address _accountTo, uint256 _amount, bool _success) internal {
    vm.mockCall(
      address(mockCollateral),
      abi.encodeCall(mockCollateral.transferFrom, (_accountFrom, _accountTo, _amount)),
      abi.encode(_success)
    );
  }

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(collateralJoin)).sig(IDisableable.contractEnabled.selector).checked_write(_contractEnabled);
  }
}

contract Unit_CollateralJoin_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Revert_Non18Decimals(uint256 _decimals) public {
    vm.assume(_decimals != 18);

    _mockDecimals(_decimals);

    vm.expectRevert('CollateralJoin/non-18-decimals');

    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));
  }

  function test_Emit_AddAuthorization() public happyPath {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(collateralJoin.contractEnabled(), 1);
  }

  function test_Set_SafeEngine() public happyPath {
    assertEq(address(collateralJoin.safeEngine()), address(mockSafeEngine));
  }

  function test_Set_CollateralType(bytes32 _cType) public happyPath {
    collateralJoin = new CollateralJoin(address(mockSafeEngine), _cType, address(mockCollateral));

    assertEq(collateralJoin.collateralType(), _cType);
  }

  function test_Set_Collateral() public happyPath {
    assertEq(address(collateralJoin.collateral()), address(mockCollateral));
  }

  function test_Set_Decimals() public happyPath {
    assertEq(collateralJoin.decimals(), 18);
  }
}

contract Unit_CollateralJoin_DisableContract is Base {
  event DisableContract();

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    collateralJoin.disableContract();
  }

  function test_Revert_ContractIsDisabled() public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralJoin.disableContract();
  }

  function test_Emit_DisableContract() public happyPath {
    expectEmitNoIndex();
    emit DisableContract();

    collateralJoin.disableContract();
  }
}

contract Unit_CollateralJoin_Join is Base {
  event Join(address _sender, address _account, uint256 _wad);

  modifier happyPath(uint256 _wad) {
    vm.startPrank(user);

    _assumeHappyPath(_wad);
    _mockValues(_wad);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal {
    vm.assume(notOverflowInt256(_wad));
  }

  function _mockValues(uint256 _wad) internal {
    _mockTransferFrom(user, address(collateralJoin), _wad, true);
  }

  function test_Revert_ContractIsDisabled(address _account, uint256 _wad) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralJoin.join(_account, _wad);
  }

  function test_Revert_IntOverflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowInt256(_wad));

    vm.expectRevert(Math.IntOverflow.selector);

    collateralJoin.join(_account, _wad);
  }

  function test_Revert_FailedTransfer(address _account, uint256 _wad) public {
    vm.startPrank(user);
    vm.assume(int256(_wad) >= 0);

    _mockTransferFrom(user, address(collateralJoin), _wad, false);

    vm.expectRevert('CollateralJoin/failed-transfer');

    collateralJoin.join(_account, _wad);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(address _account, uint256 _wad) public happyPath(_wad) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, _account, int256(_wad)))
    );

    collateralJoin.join(_account, _wad);
  }

  function test_Emit_Join(address _account, uint256 _wad) public happyPath(_wad) {
    expectEmitNoIndex();
    emit Join(user, _account, _wad);

    collateralJoin.join(_account, _wad);
  }
}

contract Unit_CollateralJoin_Exit is Base {
  event Exit(address _sender, address _account, uint256 _wad);

  modifier happyPath(address _account, uint256 _wad) {
    vm.startPrank(user);

    _assumeHappyPath(_wad);
    _mockValues(_account, _wad);
    _;
  }

  function _assumeHappyPath(uint256 _wad) internal {
    vm.assume(notOverflowInt256(_wad));
  }

  function _mockValues(address _account, uint256 _wad) internal {
    _mockTransfer(_account, _wad, true);
  }

  function test_Revert_IntOverflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowInt256(_wad));

    vm.expectRevert(Math.IntOverflow.selector);

    collateralJoin.exit(_account, _wad);
  }

  function test_Revert_FailedTransfer(address _account, uint256 _wad) public {
    vm.assume(notOverflowInt256(_wad));

    _mockTransfer(_account, _wad, false);

    vm.expectRevert('CollateralJoin/failed-transfer');

    collateralJoin.exit(_account, _wad);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(
    address _account,
    uint256 _wad
  ) public happyPath(_account, _wad) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, user, -int256(_wad)))
    );

    collateralJoin.exit(_account, _wad);
  }

  function test_Emit_Exit(address _account, uint256 _wad) public happyPath(_account, _wad) {
    expectEmitNoIndex();
    emit Exit(user, _account, _wad);

    collateralJoin.exit(_account, _wad);
  }
}
