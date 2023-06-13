// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata, IERC20} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
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
  IERC20Metadata mockCollateral = IERC20Metadata(mockContract('Collateral'));

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

  modifier happyPath(uint256 _decimals) {
    vm.startPrank(user);

    _assumeHappyPath(_decimals);
    _mockValues(_decimals);
    _;
  }

  function _assumeHappyPath(uint256 _decimals) internal pure {
    vm.assume(_decimals <= 18);
  }

  function _mockValues(uint256 _decimals) internal {
    _mockDecimals(_decimals);
  }

  function test_Revert_Gt18Decimals(uint256 _decimals) public {
    vm.assume(_decimals > 18);

    _mockValues(_decimals);

    // reverts with uint-underflow
    vm.expectRevert();

    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));
  }

  function test_Emit_AddAuthorization(uint256 _decimals) public happyPath(_decimals) {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));
  }

  function test_Set_ContractEnabled(uint256 _decimals) public happyPath(_decimals) {
    assertEq(collateralJoin.contractEnabled(), 1);
  }

  function test_Set_SafeEngine(uint256 _decimals) public happyPath(_decimals) {
    assertEq(address(collateralJoin.safeEngine()), address(mockSafeEngine));
  }

  function test_Set_CollateralType(bytes32 _cType, uint256 _decimals) public happyPath(_decimals) {
    collateralJoin = new CollateralJoin(address(mockSafeEngine), _cType, address(mockCollateral));

    assertEq(collateralJoin.collateralType(), _cType);
  }

  function test_Set_Collateral(uint256 _decimals) public happyPath(_decimals) {
    assertEq(address(collateralJoin.collateral()), address(mockCollateral));
  }

  function test_Set_Decimals(uint256 _decimals) public happyPath(_decimals) {
    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));

    assertEq(collateralJoin.decimals(), _decimals);
  }

  function test_Set_Multiplier(uint256 _decimals) public happyPath(_decimals) {
    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));

    assertEq(collateralJoin.multiplier(), 18 - _decimals);
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

  modifier happyPath(uint256 _wad, uint256 _decimals) {
    vm.startPrank(user);

    _assumeHappyPath(_wad, _decimals);
    _mockValues(_wad, _decimals, true);

    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));
    _;
  }

  function _assumeHappyPath(uint256 _wad, uint256 _decimals) internal pure {
    vm.assume(notOverflowInt256(_wad));
    vm.assume(_decimals <= 18);
  }

  function _mockValues(uint256 _wad, uint256 _decimals, bool _transferFrom) internal {
    _mockDecimals(_decimals);
    _mockTransferFrom(user, address(collateralJoin), _wad, _transferFrom);
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

  function test_Revert_FailedTransfer(address _account, uint256 _wad, uint256 _decimals) public {
    vm.startPrank(user);
    vm.assume(notOverflowInt256(_wad));

    _mockValues(_wad, _decimals, false);

    vm.expectRevert('SafeERC20: ERC20 operation did not succeed');

    collateralJoin.join(_account, _wad);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(
    address _account,
    uint256 _wad,
    uint256 _decimals
  ) public happyPath(_wad, _decimals) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, _account, int256(_wad)))
    );

    collateralJoin.join(_account, _wad);
  }

  function test_Call_Collateral_TransferFrom(
    address _account,
    uint256 _wad,
    uint256 _decimals
  ) public happyPath(_wad, _decimals) {
    vm.expectCall(
      address(mockCollateral),
      abi.encodeCall(IERC20.transferFrom, (user, address(collateralJoin), _wad / 10 ** (18 - _decimals)))
    );

    collateralJoin.join(_account, _wad);
  }

  function test_Emit_Join(address _account, uint256 _wad, uint256 _decimals) public happyPath(_wad, _decimals) {
    expectEmitNoIndex();
    emit Join(user, _account, _wad);

    collateralJoin.join(_account, _wad);
  }
}

contract Unit_CollateralJoin_Exit is Base {
  event Exit(address _sender, address _account, uint256 _wad);

  modifier happyPath(address _account, uint256 _wad, uint256 _decimals) {
    vm.startPrank(user);

    _assumeHappyPath(_wad, _decimals);
    _mockValues(_account, _wad, _decimals, true);

    collateralJoin = new CollateralJoin(address(mockSafeEngine), collateralType, address(mockCollateral));
    _;
  }

  function _assumeHappyPath(uint256 _wad, uint256 _decimals) internal pure {
    vm.assume(notOverflowInt256(_wad));
    vm.assume(_decimals <= 18);
  }

  function _mockValues(address _account, uint256 _wad, uint256 _decimals, bool _transfer) internal {
    _mockDecimals(_decimals);
    _mockTransfer(_account, _wad, _transfer);
  }

  function test_Revert_IntOverflow(address _account, uint256 _wad) public {
    vm.assume(!notOverflowInt256(_wad));

    vm.expectRevert(Math.IntOverflow.selector);

    collateralJoin.exit(_account, _wad);
  }

  function test_Revert_FailedTransfer(address _account, uint256 _wad, uint256 _decimals) public {
    vm.assume(notOverflowInt256(_wad));

    _mockValues(_account, _wad, _decimals, false);

    vm.expectRevert('SafeERC20: ERC20 operation did not succeed');

    collateralJoin.exit(_account, _wad);
  }

  function test_Call_SafeEngine_ModifyCollateralBalance(
    address _account,
    uint256 _wad,
    uint256 _decimals
  ) public happyPath(_account, _wad, _decimals) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.modifyCollateralBalance, (collateralType, user, -int256(_wad)))
    );

    collateralJoin.exit(_account, _wad);
  }

  function test_Call_Collateral_Transfer(
    address _account,
    uint256 _wad,
    uint256 _decimals
  ) public happyPath(_account, _wad, _decimals) {
    vm.expectCall(address(mockCollateral), abi.encodeCall(IERC20.transfer, (_account, _wad / 10 ** (18 - _decimals))));

    collateralJoin.exit(_account, _wad);
  }

  function test_Emit_Exit(
    address _account,
    uint256 _wad,
    uint256 _decimals
  ) public happyPath(_account, _wad, _decimals) {
    expectEmitNoIndex();
    emit Exit(user, _account, _wad);

    collateralJoin.exit(_account, _wad);
  }
}
