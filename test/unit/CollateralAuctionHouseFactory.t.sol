// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  CollateralAuctionHouseFactoryForTest,
  ICollateralAuctionHouseFactory
} from '@test/mocks/CollateralAuctionHouseFactoryForTest.sol';
import {
  CollateralAuctionHouseChild, ICollateralAuctionHouse
} from '@contracts/factories/CollateralAuctionHouseChild.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
import {IFactoryChild} from '@interfaces/factories/IFactoryChild.sol';
import {WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  bytes32 collateralType = bytes32('collateralType');

  address mockSafeEngine = mockContract('SafeEngine');
  address mockLiquidationEngine = mockContract('LiquidationEngine');
  address mockOracleRelayer = mockContract('OracleRelayer');
  address mockCollateralAuctionHouse = mockContract('CollateralAuctionHouse');

  CollateralAuctionHouseFactoryForTest collateralAuctionHouseFactory;
  CollateralAuctionHouseChild collateralAuctionHouseChild = CollateralAuctionHouseChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'CollateralAuctionHouseChild')
  );

  ICollateralAuctionHouse.CollateralAuctionHouseParams cahParams;

  function setUp() public virtual {
    vm.startPrank(deployer);

    // NOTE: needs valid cParams to deploy a CollateralAuctionHouseChild
    cahParams = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 1,
      minDiscount: 1,
      maxDiscount: 1,
      perSecondDiscountUpdateRate: 1
    });

    collateralAuctionHouseFactory =
    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(mockLiquidationEngine), address(mockOracleRelayer));
    label(address(collateralAuctionHouseFactory), 'CollateralAuctionHouseFactory');

    collateralAuctionHouseFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockLiquidationEngine(address _liquidationEngine) internal {
    stdstore.target(address(collateralAuctionHouseFactory)).sig(
      ICollateralAuctionHouseFactory.liquidationEngine.selector
    ).checked_write(_liquidationEngine);
  }

  function _mockCollateralAuctionHouse(bytes32 _cType, address _collateralAuctionHouse) internal {
    stdstore.target(address(collateralAuctionHouseFactory)).sig(
      ICollateralAuctionHouseFactory.collateralAuctionHouses.selector
    ).with_key(_cType).checked_write(_collateralAuctionHouse);
  }

  function _mockCollateralList(bytes32 _cType) internal {
    collateralAuctionHouseFactory.addToCollateralList(_cType);
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    collateralAuctionHouseFactory.setContractEnabled(_contractEnabled);
  }
}

contract Unit_CollateralAuctionHouseFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Revert_Null_SafeEngine() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    new CollateralAuctionHouseFactoryForTest(address(0), address(mockLiquidationEngine), address(mockOracleRelayer));
  }

  function test_Revert_Null_LiquidationEngine() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(0), address(mockOracleRelayer));
  }

  function test_Revert_Null_OracleRelayer() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(mockLiquidationEngine), address(0));
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    collateralAuctionHouseFactory =
    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(mockLiquidationEngine), address(mockOracleRelayer));
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(collateralAuctionHouseFactory.contractEnabled(), true);
  }
}

contract Unit_CollateralAuctionHouseFactory_DeployCollateralAuctionHouse is Base {
  event DeployCollateralAuctionHouse(bytes32 indexed _cType, address indexed _collateralAuctionHouse);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _cType) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));
  }

  function test_Revert_ContractIsDisabled(bytes32 _cType) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));
  }

  function test_Revert_CAHExists(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));

    vm.expectRevert(IModifiablePerCollateral.CollateralTypeAlreadyInitialized.selector);

    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));
  }

  function test_Deploy_CollateralAuctionHouseChild(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));

    assertEq(address(collateralAuctionHouseChild).code, type(CollateralAuctionHouseChild).runtimeCode);

    // params
    assertEq(address(collateralAuctionHouseChild.safeEngine()), address(mockSafeEngine));
    assertEq(address(collateralAuctionHouseChild.liquidationEngine()), address(mockLiquidationEngine));
    assertEq(address(collateralAuctionHouseChild.oracleRelayer()), address(mockOracleRelayer));
    assertEq(collateralAuctionHouseChild.collateralType(), _cType);
    assertEq(abi.encode(collateralAuctionHouseChild.params()), abi.encode(cahParams));
    assertEq(abi.encode(collateralAuctionHouseFactory.cParams(_cType)), abi.encode(cahParams));
  }

  function test_Set_CollateralList(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));

    assertEq(collateralAuctionHouseFactory.collateralList()[0], _cType);
  }

  function test_Set_CollateralAuctionHouses(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));

    assertEq(collateralAuctionHouseFactory.collateralAuctionHousesList()[0], address(collateralAuctionHouseChild));
  }

  function test_Emit_DeployCollateralAuctionHouse(bytes32 _cType) public happyPath {
    vm.expectEmit();
    emit DeployCollateralAuctionHouse(_cType, address(collateralAuctionHouseChild));

    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));
  }

  function test_Return_CollateralAuctionHouse(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.initializeCollateralType(_cType, abi.encode(cahParams));
    assertEq(
      address(collateralAuctionHouseFactory.collateralAuctionHouses(_cType)), address(collateralAuctionHouseChild)
    );
  }
}

contract Unit_CollateralAuctionHouseFactory_ModifyParameters is Base {
  event AddAuthorization(address _account);
  event RemoveAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_LiquidationEngine(address _liquidationEngine) public happyPath {
    vm.assume(_liquidationEngine != address(0));
    vm.assume(_liquidationEngine != deployer);
    vm.assume(_liquidationEngine != authorizedAccount);

    collateralAuctionHouseFactory.modifyParameters('liquidationEngine', abi.encode(_liquidationEngine));

    assertEq(collateralAuctionHouseFactory.liquidationEngine(), _liquidationEngine);
  }

  function test_Emit_Authorization_LiquidationEngine(
    address _oldLiquidationEngine,
    address _newLiquidationEngine
  ) public happyPath {
    vm.assume(_newLiquidationEngine != address(0));
    vm.assume(_newLiquidationEngine != deployer);
    vm.assume(_newLiquidationEngine != authorizedAccount);
    vm.assume(_oldLiquidationEngine != deployer);
    vm.assume(_oldLiquidationEngine != authorizedAccount);

    _mockLiquidationEngine(_oldLiquidationEngine);
    collateralAuctionHouseFactory.removeAuthorization(address(mockLiquidationEngine));
    collateralAuctionHouseFactory.addAuthorization(_oldLiquidationEngine);

    if (_oldLiquidationEngine != address(0)) {
      vm.expectEmit();
      emit RemoveAuthorization(_oldLiquidationEngine);
    }
    vm.expectEmit();
    emit AddAuthorization(_newLiquidationEngine);

    collateralAuctionHouseFactory.modifyParameters('liquidationEngine', abi.encode(_newLiquidationEngine));
  }

  function test_Set_OracleRelayer(address _oracleRelayer) public happyPath {
    vm.assume(_oracleRelayer != address(0));

    collateralAuctionHouseFactory.modifyParameters('oracleRelayer', abi.encode(_oracleRelayer));

    assertEq(collateralAuctionHouseFactory.oracleRelayer(), _oracleRelayer);
  }

  function test_Revert_LiquidationEngine_NullAddress() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAddress.selector);

    collateralAuctionHouseFactory.modifyParameters('liquidationEngine', abi.encode(0));
  }

  function test_Revert_OracleRelayer_NullAddress() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAddress.selector);

    collateralAuctionHouseFactory.modifyParameters('oracleRelayer', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    collateralAuctionHouseFactory.modifyParameters('unrecognizedParam', _data);
  }
}

contract Unit_CollateralAuctionHouseFactory_ModifyParametersPerCollateral is Base {
  modifier happyPath(bytes32 _cType) {
    vm.startPrank(authorizedAccount);

    _mockValues(_cType);
    _;
  }

  function _mockValues(bytes32 _cType) internal {
    _mockCollateralAuctionHouse(_cType, address(mockCollateralAuctionHouse));
    _mockCollateralList(_cType);
  }

  function test_Revert_UnrecognizedCType(bytes32 _cType, bytes32 _param, bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedCType.selector);

    collateralAuctionHouseFactory.modifyParameters(_cType, _param, _data);
  }

  function test_Call_CollateralAuctionHouse_ModifyParameters(
    bytes32 _cType,
    bytes32 _param,
    bytes memory _data
  ) public happyPath(_cType) {
    vm.expectCall(
      address(mockCollateralAuctionHouse), abi.encodeWithSignature('modifyParameters(bytes32,bytes)', _param, _data), 1
    );

    collateralAuctionHouseFactory.modifyParameters(_cType, _param, _data);
  }
}
