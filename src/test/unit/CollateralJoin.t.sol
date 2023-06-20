// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {CollateralJoinForTest, ICollateralJoin} from '@contracts/for-test/CollateralJoinForTest.sol';
import {ICollateralJoinFactory} from '@interfaces/utils/ICollateralJoinFactory.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata, IERC20} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
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

  ICollateralJoinFactory mockCollateralJoinFactory = ICollateralJoinFactory(mockContract('CollateralJoinFactory'));
  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IERC20Metadata mockCollateral = IERC20Metadata(mockContract('Collateral'));

  CollateralJoinForTest collateralJoin;

  // CollateralJoin storage
  bytes32 collateralType = 'collateralType';

  function setUp() public virtual {
    vm.startPrank(address(mockCollateralJoinFactory));

    _mockDecimals(18);

    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));
    label(address(collateralJoin), 'CollateralJoin');

    collateralJoin.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockFactoryEnabled(uint256 _factoryEnabled) internal {
    vm.mockCall(
      address(mockCollateralJoinFactory),
      abi.encodeCall(mockCollateralJoinFactory.contractEnabled, ()),
      abi.encode(_factoryEnabled)
    );
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

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(collateralJoin)).sig(IDisableable.contractEnabled.selector).checked_write(_contractEnabled);
  }
}

contract Unit_CollateralJoin_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath(uint8 _decimals) {
    vm.startPrank(address(mockCollateralJoinFactory));

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
    expectEmitNoIndex();
    emit AddAuthorization(address(mockCollateralJoinFactory));

    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));
  }

  function test_Set_ContractEnabled(uint8 _decimals) public happyPath(_decimals) {
    assertEq(collateralJoin.contractEnabled(), 1);
  }

  function test_Set_CollateralJoinFactory(uint8 _decimals) public happyPath(_decimals) {
    assertEq(address(collateralJoin.collateralJoinFactory()), address(mockCollateralJoinFactory));
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
    _assumeHappyPath(_wei, _decimals);
    _mockValues(_wei, _decimals, true);

    vm.prank(address(mockCollateralJoinFactory));
    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));

    vm.startPrank(user);
    _;
  }

  function _assumeHappyPath(uint256 _wei, uint8 _decimals) internal pure {
    vm.assume(_decimals <= 18);
    vm.assume(notOverflowMul(_wei, 10 ** (18 - _decimals)));
    vm.assume(notOverflowInt256(_wei * 10 ** (18 - _decimals)));
  }

  function _mockValues(uint256 _wei, uint8 _decimals, bool _transferFrom) internal {
    _mockFactoryEnabled(1);
    _mockDecimals(_decimals);
    _mockTransferFrom(user, address(collateralJoin), _wei, _transferFrom);
  }

  function test_Revert_ContractIsDisabled(address _account, uint256 _wei) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralJoin.join(_account, _wei);
  }

  function test_Revert_FactoryIsDisabled(address _account, uint256 _wei) public {
    _mockFactoryEnabled(0);

    vm.expectRevert(ICollateralJoin.CollateralJoin_FactoryIsDisabled.selector);

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

    vm.expectRevert('SafeERC20: ERC20 operation did not succeed');

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

    expectEmitNoIndex();
    emit Join(user, _account, _wad);

    collateralJoin.join(_account, _wei);
  }
}

contract Unit_CollateralJoin_Exit is Base {
  event Exit(address _sender, address _account, uint256 _wad);

  modifier happyPath(address _account, uint256 _wei, uint8 _decimals) {
    _assumeHappyPath(_wei, _decimals);
    _mockValues(_account, _wei, _decimals, true);

    vm.prank(address(mockCollateralJoinFactory));
    collateralJoin = new CollateralJoinForTest(address(mockSafeEngine), collateralType, address(mockCollateral));

    vm.startPrank(user);
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

    vm.expectRevert('SafeERC20: ERC20 operation did not succeed');

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

    expectEmitNoIndex();
    emit Exit(user, _account, _wad);

    collateralJoin.exit(_account, _wei);
  }
}

contract Unit_CollateralJoin_WhenFactoryEnabled is Base {
  modifier happyPath() {
    _mockFactoryEnabled(1);
    _;
  }

  function test_Revert_FactoryIsDisabled() public {
    _mockFactoryEnabled(0);

    vm.expectRevert(ICollateralJoin.CollateralJoin_FactoryIsDisabled.selector);

    collateralJoin.whenFactoryEnabledModifier();
  }

  function testFail_WhenFactoryEnabled() public happyPath {
    vm.expectRevert(ICollateralJoin.CollateralJoin_FactoryIsDisabled.selector);

    collateralJoin.whenFactoryEnabledModifier();
  }
}
