// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  CollateralJoinFactoryForTest, ICollateralJoinFactory
} from '@contracts/for-test/CollateralJoinFactoryForTest.sol';
import {CollateralJoinChild} from '@contracts/factories/CollateralJoinChild.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

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

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(collateralJoinFactory)).sig(IDisableable.contractEnabled.selector).checked_write(
      _contractEnabled
    );
  }

  function _mockCollateralJoin(address _collateralJoin) internal {
    collateralJoinFactory.addCollateralJoin(_collateralJoin);
  }
}

contract Unit_CollateralJoinFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    collateralJoinFactory = new CollateralJoinFactoryForTest(address(mockSafeEngine));
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(collateralJoinFactory.contractEnabled(), 1);
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

    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));
  }

  function test_Deploy_CollateralJoinChild(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));

    assertEq(address(collateralJoinChild).code, type(CollateralJoinChild).runtimeCode);

    // params
    assertEq(address(collateralJoinChild.safeEngine()), address(mockSafeEngine));
    assertEq(address(collateralJoinChild.collateral()), address(mockCollateral));
    assertEq(collateralJoinChild.collateralType(), _cType);
  }

  function test_Set_CollateralJoins(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));

    assertEq(collateralJoinFactory.collateralJoinsList()[0], address(collateralJoinChild));
  }

  function test_Emit_DeployCollateralJoin(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    expectEmitNoIndex();
    emit DeployCollateralJoin(_cType, address(mockCollateral), address(collateralJoinChild));

    collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral));
  }

  function test_Return_CollateralJoin(bytes32 _cType, uint8 _decimals) public happyPath(_decimals) {
    assertEq(collateralJoinFactory.deployCollateralJoin(_cType, address(mockCollateral)), address(collateralJoinChild));
  }
}

contract Unit_CollateralJoinFactory_DisableCollateralJoin is Base {
  event DisableCollateralJoin(address indexed _collateralJoin);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    vm.etch(address(collateralJoinChild), new bytes(0x1));

    _mockValues(address(collateralJoinChild));
    _;
  }

  function _mockValues(address _collateralJoin) internal {
    _mockCollateralJoin(_collateralJoin);
  }

  function test_Revert_Unauthorized(address _collateralJoin) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    collateralJoinFactory.disableCollateralJoin(_collateralJoin);
  }

  function test_Revert_NotCollateralJoin(address _collateralJoin) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(ICollateralJoinFactory.CollateralJoinFactory_NotCollateralJoin.selector);

    collateralJoinFactory.disableCollateralJoin(_collateralJoin);
  }

  function test_Set_CollateralJoins() public happyPath {
    collateralJoinFactory.disableCollateralJoin(address(collateralJoinChild));

    assertEq(collateralJoinFactory.collateralJoinsList(), new address[](0));
  }

  function test_Call_CollateralJoin_DisableContract() public happyPath {
    vm.expectCall(address(collateralJoinChild), abi.encodeCall(collateralJoinChild.disableContract, ()));

    collateralJoinFactory.disableCollateralJoin(address(collateralJoinChild));
  }

  function test_Emit_DisableCollateralJoin() public happyPath {
    expectEmitNoIndex();
    emit DisableCollateralJoin(address(collateralJoinChild));

    collateralJoinFactory.disableCollateralJoin(address(collateralJoinChild));
  }
}
