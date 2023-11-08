// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {CollateralJoinFactoryForTest, ICollateralJoinFactory} from '@test/mocks/CollateralJoinFactoryForTest.sol';
import {CollateralJoinChild} from '@contracts/factories/CollateralJoinChild.sol';
import {CollateralJoinDelegatableChild} from '@contracts/factories/CollateralJoinDelegatableChild.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IVotes} from '@openzeppelin/contracts/governance/utils/IVotes.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  bytes32 collateralType = bytes32('collateralType');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IERC20Metadata mockCollateral = IERC20Metadata(mockContract('Collateral'));

  CollateralJoinFactoryForTest collateralJoinFactory;
  CollateralJoinChild collateralJoinChild = CollateralJoinChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'CollateralJoinChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    collateralJoinFactory = new CollateralJoinFactoryForTest(address(mockSafeEngine));
    label(address(collateralJoinFactory), 'CollateralJoinFactory');

    collateralJoinFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockDecimals(uint8 _decimals) internal {
    vm.mockCall(address(mockCollateral), abi.encodeCall(mockCollateral.decimals, ()), abi.encode(_decimals));
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    collateralJoinFactory.setContractEnabled(_contractEnabled);
  }

  function _mockCollateralJoin(bytes32 _cType, address _collateralJoin) internal {
    collateralJoinFactory.addCollateralJoin(_cType, _collateralJoin);
  }
}

contract Unit_CollateralJoinFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Revert_Null_SafeEngine() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    new CollateralJoinFactoryForTest(address(0));
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    collateralJoinFactory = new CollateralJoinFactoryForTest(address(mockSafeEngine));
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(collateralJoinFactory.contractEnabled(), true);
  }
}

contract Unit_CollateralJoinFactory_DeployCollateralJoin is Base {
  event DeployCollateralJoin(bytes32 indexed _cType, address indexed _collateral, address indexed _collateralJoin);

  modifier happyPath(uint8 _decimals) {
    vm.startPrank(authorizedAccount);

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

  function test_Revert_Unauthorized(bytes32 _cType) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));
  }

  function test_Revert_ContractIsDisabled(bytes32 _cType) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));
  }

  function test_Revert_RepeatedCType(bytes32 _cType, address _otherCollateral) public happyPath(18) {
    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));

    vm.expectRevert(ICollateralJoinFactory.CollateralJoinFactory_CollateralJoinExistent.selector);

    collateralJoinFactory.deployCollateralJoin(_cType, address(_otherCollateral));
  }

  function test_Deploy_CollateralJoinChild(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));

    assertEq(address(collateralJoinChild).code, type(CollateralJoinChild).runtimeCode);

    // params
    assertEq(address(collateralJoinChild.safeEngine()), address(mockSafeEngine));
    assertEq(address(collateralJoinChild.collateral()), address(mockCollateral));
    assertEq(collateralJoinChild.collateralType(), _cType);
  }

  function test_Set_CollateralTypes(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));

    assertEq(collateralJoinFactory.collateralTypesList()[0], _cType);
  }

  function test_Set_CollateralJoins(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));

    assertEq(collateralJoinFactory.collateralJoinsList()[0], address(collateralJoinChild));
  }

  function test_Emit_DeployCollateralJoin(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    vm.expectEmit();
    emit DeployCollateralJoin(_cType, address(mockCollateral), address(collateralJoinChild));

    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));
  }

  function test_Return_CollateralJoin(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    assertEq(
      address(collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral))), address(collateralJoinChild)
    );
  }

  function test_Call_SafeEngineAuth(bytes32 _cType) public happyPath(18) {
    vm.expectCall(address(mockSafeEngine), abi.encodeCall(IAuthorizable.addAuthorization, address(collateralJoinChild)));

    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));
  }
}

contract Unit_CollateralJoinFactory_DeployDelegatableCollateralJoin is Base {
  event DeployCollateralJoin(bytes32 indexed _cType, address indexed _collateral, address indexed _collateralJoin);

  address delegatee;

  function setUp() public override {
    super.setUp();

    delegatee = newAddress();
  }

  modifier happyPath(uint8 _decimals) {
    vm.startPrank(authorizedAccount);

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

  function test_Revert_Unauthorized(bytes32 _cType) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee);
  }

  function test_Revert_ContractIsDisabled(bytes32 _cType) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee);
  }

  function test_Revert_RepeatedCType(bytes32 _cType, address _otherCollateral) public happyPath(18) {
    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));

    vm.expectRevert(ICollateralJoinFactory.CollateralJoinFactory_CollateralJoinExistent.selector);

    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(_otherCollateral), delegatee);
  }

  function test_Deploy_CollateralJoinDelegatableChild(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee);

    assertEq(address(collateralJoinChild).code, type(CollateralJoinDelegatableChild).runtimeCode);

    // params
    assertEq(address(collateralJoinChild.safeEngine()), address(mockSafeEngine));
    assertEq(address(collateralJoinChild.collateral()), address(mockCollateral));
    assertEq(collateralJoinChild.collateralType(), _cType);
  }

  function test_Revert_NullDelegatee(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    vm.expectRevert(Assertions.NullAddress.selector);
    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), address(0));
  }

  function test_Set_CollateralTypes(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee);

    assertEq(collateralJoinFactory.collateralTypesList()[0], _cType);
  }

  function test_Set_CollateralJoins(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee);

    assertEq(collateralJoinFactory.collateralJoinsList()[0], address(collateralJoinChild));
  }

  function test_Emit_DeployCollateralJoin(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    vm.expectEmit();
    emit DeployCollateralJoin(_cType, address(mockCollateral), address(collateralJoinChild));

    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee);
  }

  function test_Return_CollateralJoin(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    assertEq(
      address(collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee)),
      address(collateralJoinChild)
    );
  }

  function test_Call_SafeEngineAuth(bytes32 _cType) public happyPath(18) {
    vm.expectCall(address(mockSafeEngine), abi.encodeCall(IAuthorizable.addAuthorization, address(collateralJoinChild)));

    collateralJoinFactory.deployDelegatableCollateralJoin(_cType, address(mockCollateral), delegatee);
  }

  function test_Call_ERC20Votes_Delegate() public happyPath(18) {
    vm.expectCall(address(mockCollateral), abi.encodeCall(IVotes.delegate, (delegatee)));

    collateralJoinFactory.deployDelegatableCollateralJoin(collateralType, address(mockCollateral), delegatee);
  }
}

contract Unit_CollateralJoinFactory_DisableCollateralJoin is Base {
  event DisableCollateralJoin(address indexed _collateralJoin);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    vm.etch(address(collateralJoinChild), new bytes(0x1));

    _mockValues(collateralType, address(collateralJoinChild));
    _;
  }

  function _mockValues(bytes32 _cType, address _collateralJoin) internal {
    _mockCollateralJoin(_cType, _collateralJoin);
  }

  function test_Revert_Unauthorized(bytes32 _cType) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    collateralJoinFactory.disableCollateralJoin(_cType);
  }

  function test_Revert_NotCollateralJoin(bytes32 _cType) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(ICollateralJoinFactory.CollateralJoinFactory_CollateralJoinNonExistent.selector);

    collateralJoinFactory.disableCollateralJoin(_cType);
  }

  function test_Set_CollateralTypes() public happyPath {
    collateralJoinFactory.disableCollateralJoin(collateralType);

    bytes32[] memory _collateralTypesList = collateralJoinFactory.collateralTypesList();
    // NOTE: assertEq(bytes32[],bytes32[]) is not supported
    assertEq(_collateralTypesList.length, 0);
  }

  function test_Set_CollateralJoins() public happyPath {
    collateralJoinFactory.disableCollateralJoin(collateralType);

    assertEq(collateralJoinFactory.collateralJoinsList(), new address[](0));
  }

  function test_Call_CollateralJoin_DisableContract() public happyPath {
    vm.expectCall(address(collateralJoinChild), abi.encodeCall(collateralJoinChild.disableContract, ()));

    collateralJoinFactory.disableCollateralJoin(collateralType);
  }

  function test_Emit_DisableCollateralJoin() public happyPath {
    vm.expectEmit();
    emit DisableCollateralJoin(address(collateralJoinChild));

    collateralJoinFactory.disableCollateralJoin(collateralType);
  }
}
