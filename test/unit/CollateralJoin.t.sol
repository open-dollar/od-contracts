// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CollateralJoinForTest, ICollateralJoin} from '@test/mocks/CollateralJoinForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IERC20Metadata, IERC20} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Math} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IERC20Metadata mockCollateral = IERC20Metadata(mockContract('Collateral'));

  CollateralJoinForTest collateralJoin;

  // CollateralJoin storage
  bytes32 collateralType = 'collateralType';

  function setUp() public virtual {
    vm.startPrank(deployer);

    _mockDecimals(18);

    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));
    label(address(collateralJoin), 'CollateralJoin');

    collateralJoin.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockDecimals(uint8 _decimals) internal {
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

  function _mockContractEnabled(bool _contractEnabled) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    collateralJoin.setContractEnabled(_contractEnabled);
  }
}

contract Unit_CollateralJoin_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath(uint8 _decimals) {
    vm.startPrank(user);

    _assumeHappyPath(_decimals);
    _mockValues(_decimals);
    _;
  }

  function _assumeHappyPath(uint8 _decimals) internal pure {
    vm.assume(_decimals <= 18);
  }

  function _mockValues(uint8 _decimals) internal {
    _mockDecimals(_decimals);
  }

  function test_Revert_Gt18Decimals(uint8 _decimals) public {
    vm.assume(_decimals > 18);

    _mockValues(_decimals);

    // reverts with uint-underflow
    vm.expectRevert();

    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));
  }

  function test_Emit_AddAuthorization(uint8 _decimals) public happyPath(_decimals) {
    vm.expectEmit();
    emit AddAuthorization(user);

    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));
  }

  function test_Set_ContractEnabled(uint8 _decimals) public happyPath(_decimals) {
    assertEq(collateralJoin.contractEnabled(), true);
  }

  function test_Set_SafeEngine(uint8 _decimals) public happyPath(_decimals) {
    assertEq(address(collateralJoin.safeEngine()), address(mockSafeEngine));
  }

  function test_Set_CollateralType(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), _cType, address(mockCollateral));

    assertEq(collateralJoin.collateralType(), _cType);
  }

  function test_Set_Collateral(uint8 _decimals) public happyPath(_decimals) {
    assertEq(address(collateralJoin.collateral()), address(mockCollateral));
  }

  function test_Set_Decimals(uint8 _decimals) public happyPath(_decimals) {
    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));

    assertEq(collateralJoin.decimals(), _decimals);
  }

  function test_Set_Multiplier(uint8 _decimals) public happyPath(_decimals) {
    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));

    assertEq(collateralJoin.multiplier(), 18 - _decimals);
  }

  function test_Revert_NullSafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    collateralJoin = new CollateralJoinForTest(address(0), collateralType, address(mockCollateral));
  }
}

contract Unit_CollateralJoin_Join is Base {
  event Join(address _sender, address _account, uint256 _wad);

  modifier happyPath(uint256 _wei, uint8 _decimals) {
    vm.startPrank(user);

    _assumeHappyPath(_wei, _decimals);
    _mockValues(_wei, _decimals, true);

    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));
    _;
  }

  function _assumeHappyPath(uint256 _wei, uint8 _decimals) internal pure {
    vm.assume(_decimals <= 18);
    vm.assume(notOverflowMul(_wei, 10 ** (18 - _decimals)));
    vm.assume(notOverflowInt256(_wei * 10 ** (18 - _decimals)));
  }

  function _mockValues(uint256 _wei, uint8 _decimals, bool _transferFromReturn) internal {
    _mockDecimals(_decimals);
    _mockTransferFrom(user, address(collateralJoin), _wei, _transferFromReturn);
  }

  function test_Revert_ContractIsDisabled(address _account, uint256 _wei) public {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralJoin.join(_account, _wei);
  }

  function test_Revert_IntOverflow(address _account, uint256 _wei) public {
    vm.assume(!notOverflowInt256(_wei));

    _mockValues(_wei, 0, false);

    vm.expectRevert(Math.IntOverflow.selector);

    collateralJoin.join(_account, _wei);
  }

  function test_Revert_FailedTransfer(address _account, uint256 _wei, uint8 _decimals) public {
    vm.startPrank(user);
    vm.assume(notOverflowInt256(_wei));

    _mockValues(_wei, _decimals, false);

    vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(mockCollateral)));

    collateralJoin.join(_account, _wei);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(
    address _account,
    uint256 _wei,
    uint8 _decimals
  ) public happyPath(_wei, _decimals) {
    uint256 _wad = _wei * 10 ** (18 - _decimals);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, _account, int256(_wad))),
      1
    );

    collateralJoin.join(_account, _wei);
  }

  function test_Call_Collateral_TransferFrom(
    address _account,
    uint256 _wei,
    uint8 _decimals
  ) public happyPath(_wei, _decimals) {
    vm.expectCall(
      address(mockCollateral), abi.encodeCall(IERC20.transferFrom, (user, address(collateralJoin), _wei)), 1
    );

    collateralJoin.join(_account, _wei);
  }

  function test_Emit_Join(address _account, uint256 _wei, uint8 _decimals) public happyPath(_wei, _decimals) {
    uint256 _wad = _wei * 10 ** (18 - _decimals);

    vm.expectEmit();
    emit Join(user, _account, _wad);

    collateralJoin.join(_account, _wei);
  }
}

contract Unit_CollateralJoin_Exit is Base {
  event Exit(address _sender, address _account, uint256 _wad);

  modifier happyPath(address _account, uint256 _wei, uint8 _decimals) {
    vm.startPrank(user);

    _assumeHappyPath(_wei, _decimals);
    _mockValues(_account, _wei, _decimals, true);

    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));
    _;
  }

  function _assumeHappyPath(uint256 _wei, uint8 _decimals) internal pure {
    vm.assume(_decimals <= 18);
    vm.assume(notOverflowMul(_wei, 10 ** (18 - _decimals)));
    vm.assume(notOverflowInt256(_wei * 10 ** (18 - _decimals)));
  }

  function _mockValues(address _account, uint256 _wei, uint8 _decimals, bool _transfer) internal {
    _mockDecimals(_decimals);
    _mockTransfer(_account, _wei, _transfer);
  }

  function test_Revert_IntOverflow(address _account, uint256 _wei) public {
    vm.assume(!notOverflowInt256(_wei));

    vm.expectRevert(Math.IntOverflow.selector);

    collateralJoin.exit(_account, _wei);
  }

  function test_Revert_FailedTransfer(address _account, uint256 _wei, uint8 _decimals) public {
    vm.assume(notOverflowInt256(_wei));

    _mockValues(_account, _wei, _decimals, false);

    vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(mockCollateral)));

    collateralJoin.exit(_account, _wei);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(
    address _account,
    uint256 _wei,
    uint8 _decimals
  ) public happyPath(_account, _wei, _decimals) {
    uint256 _wad = _wei * 10 ** (18 - _decimals);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, user, -int256(_wad))),
      1
    );

    collateralJoin.exit(_account, _wei);
  }

  function test_Call_Collateral_Transfer(
    address _account,
    uint256 _wei,
    uint8 _decimals
  ) public happyPath(_account, _wei, _decimals) {
    vm.expectCall(address(mockCollateral), abi.encodeCall(IERC20.transfer, (_account, _wei)), 1);

    collateralJoin.exit(_account, _wei);
  }

  function test_Emit_Exit(address _account, uint256 _wei, uint8 _decimals) public happyPath(_account, _wei, _decimals) {
    uint256 _wad = _wei * 10 ** (18 - _decimals);

    vm.expectEmit();
    emit Exit(user, _account, _wad);

    collateralJoin.exit(_account, _wei);
  }
}
