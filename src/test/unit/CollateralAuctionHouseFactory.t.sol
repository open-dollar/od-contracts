// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  CollateralAuctionHouseFactoryForTest,
  ICollateralAuctionHouseFactory
} from '@contracts/for-test/CollateralAuctionHouseFactoryForTest.sol';
import {
  CollateralAuctionHouseChild, ICollateralAuctionHouse
} from '@contracts/factories/CollateralAuctionHouseChild.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
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
  address mockOracleRelayer = mockContract('OracleRelayer');
  address mockLiquidationEngine = mockContract('LiquidationEngine');
  address mockCollateralAuctionHouse = mockContract('CollateralAuctionHouse');

  CollateralAuctionHouseFactoryForTest collateralAuctionHouseFactory;
  CollateralAuctionHouseChild collateralAuctionHouseChild = CollateralAuctionHouseChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'CollateralAuctionHouseChild')
  );

  ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams _cahParams;
  ICollateralAuctionHouse.CollateralAuctionHouseParams _cahCParams;

  function setUp() public virtual {
    vm.startPrank(deployer);

    // NOTE: needs valid cParams to deploy a CollateralAuctionHouseChild
    _cahParams = ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams({
      minSystemCoinDeviation: 1,
      lowerSystemCoinDeviation: 1,
      upperSystemCoinDeviation: 1
    });
    _cahCParams = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 1,
      minDiscount: 1,
      maxDiscount: 1,
      perSecondDiscountUpdateRate: 1,
      lowerCollateralDeviation: 1,
      upperCollateralDeviation: 1
    });

    collateralAuctionHouseFactory =
    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(mockOracleRelayer), address(mockLiquidationEngine), _cahParams);
    label(address(collateralAuctionHouseFactory), 'CollateralAuctionHouseFactory');

    collateralAuctionHouseFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    collateralAuctionHouseFactory.setContractEnabled(_contractEnabled);
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
}

contract Unit_CollateralAuctionHouseFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Revert_Null_SafeEngine() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    new CollateralAuctionHouseFactoryForTest(address(0), address(mockOracleRelayer), address(mockLiquidationEngine), _cahParams);
  }

  function test_Revert_Null_OracleRelayer() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(0), address(mockLiquidationEngine), _cahParams);
  }

  function test_Revert_Null_LiquidationEngine() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(mockOracleRelayer), address(0), _cahParams);
  }

  function test_Emit_AddAuthorization() public happyPath {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    collateralAuctionHouseFactory =
    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(mockOracleRelayer), address(mockLiquidationEngine), _cahParams);
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(collateralAuctionHouseFactory.contractEnabled(), true);
  }

  function test_Set_GlobalParams(ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams)
    public
    happyPath
  {
    vm.assume(_cahParams.lowerSystemCoinDeviation <= WAD);
    vm.assume(_cahParams.upperSystemCoinDeviation <= WAD);
    collateralAuctionHouseFactory =
    new CollateralAuctionHouseFactoryForTest(address(mockSafeEngine), address(mockOracleRelayer), address(mockLiquidationEngine), _cahParams);

    assertEq(abi.encode(collateralAuctionHouseFactory.params()), abi.encode(_cahParams));
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

    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);
  }

  function test_Revert_ContractIsDisabled(bytes32 _cType) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);
  }

  function test_Revert_CAHExists(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);

    vm.expectRevert(ICollateralAuctionHouseFactory.CAHFactory_CAHExists.selector);

    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);
  }

  function test_Deploy_CollateralAuctionHouseChild(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);

    assertEq(address(collateralAuctionHouseChild).code, type(CollateralAuctionHouseChild).runtimeCode);

    // params
    assertEq(address(collateralAuctionHouseChild.safeEngine()), address(mockSafeEngine));
    assertEq(address(collateralAuctionHouseChild.oracleRelayer()), address(mockOracleRelayer));
    assertEq(address(collateralAuctionHouseChild.liquidationEngine()), address(mockLiquidationEngine));
    assertEq(abi.encode(collateralAuctionHouseFactory.cParams(_cType)), abi.encode(_cahCParams));
    assertEq(abi.encode(collateralAuctionHouseChild.params()), abi.encode(_cahParams));
    assertEq(abi.encode(collateralAuctionHouseChild.cParams()), abi.encode(_cahCParams));
    assertEq(collateralAuctionHouseChild.collateralType(), _cType);
  }

  function test_Set_CollateralList(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);

    assertEq(collateralAuctionHouseFactory.collateralList()[0], _cType);
  }

  function test_Set_CollateralAuctionHouses(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);

    assertEq(collateralAuctionHouseFactory.collateralAuctionHousesList()[0], address(collateralAuctionHouseChild));
  }

  function test_Emit_DeployCollateralAuctionHouse(bytes32 _cType) public happyPath {
    expectEmitNoIndex();
    emit DeployCollateralAuctionHouse(_cType, address(collateralAuctionHouseChild));

    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);
  }

  function test_Return_CollateralAuctionHouse(bytes32 _cType) public happyPath {
    assertEq(
      collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams),
      address(collateralAuctionHouseChild)
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

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    collateralAuctionHouseFactory.modifyParameters('unrecognizedParam', _data);
  }

  function test_Set_Parameters(ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _fuzz)
    public
    happyPath
  {
    vm.assume(_fuzz.lowerSystemCoinDeviation <= WAD);
    vm.assume(_fuzz.upperSystemCoinDeviation <= WAD);

    collateralAuctionHouseFactory.modifyParameters('minSystemCoinDeviation', abi.encode(_fuzz.minSystemCoinDeviation));
    collateralAuctionHouseFactory.modifyParameters(
      'lowerSystemCoinDeviation', abi.encode(_fuzz.lowerSystemCoinDeviation)
    );
    collateralAuctionHouseFactory.modifyParameters(
      'upperSystemCoinDeviation', abi.encode(_fuzz.upperSystemCoinDeviation)
    );

    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _params =
      collateralAuctionHouseFactory.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_Revert_LowerSystemCoinDeviation_NotLesserOrEqualThan(uint256 _lowerSystemCoinDeviation) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_lowerSystemCoinDeviation > WAD);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _lowerSystemCoinDeviation, WAD));

    collateralAuctionHouseFactory.modifyParameters('lowerSystemCoinDeviation', abi.encode(_lowerSystemCoinDeviation));
  }

  function test_Revert_UpperSystemCoinDeviation_NotLesserOrEqualThan(uint256 _upperSystemCoinDeviation) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_upperSystemCoinDeviation > WAD);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _upperSystemCoinDeviation, WAD));

    collateralAuctionHouseFactory.modifyParameters('upperSystemCoinDeviation', abi.encode(_upperSystemCoinDeviation));
  }

  function test_Set_OracleRelayer(address _oracleRelayer) public happyPath {
    vm.assume(_oracleRelayer != address(0));

    collateralAuctionHouseFactory.modifyParameters('oracleRelayer', abi.encode(_oracleRelayer));

    assertEq(collateralAuctionHouseFactory.oracleRelayer(), _oracleRelayer);
  }

  function test_Revert_OracleRelayer_NullAddress() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAddress.selector);

    collateralAuctionHouseFactory.modifyParameters('oracleRelayer', abi.encode(0));
  }

  function test_Set_LiquidationEngine(address _liquidationEngine) public happyPath {
    vm.assume(_liquidationEngine != address(0));
    vm.assume(_liquidationEngine != deployer);
    vm.assume(_liquidationEngine != authorizedAccount);

    collateralAuctionHouseFactory.modifyParameters('liquidationEngine', abi.encode(_liquidationEngine));

    assertEq(collateralAuctionHouseFactory.liquidationEngine(), _liquidationEngine);
  }

  function test_Emit_LiquidationEngine_Authorization(
    address _oldLiquidationEngine,
    address _newLiquidationEngine
  ) public happyPath {
    vm.assume(_newLiquidationEngine != address(0));
    vm.assume(_newLiquidationEngine != _oldLiquidationEngine);
    vm.assume(_newLiquidationEngine != deployer);
    vm.assume(_newLiquidationEngine != authorizedAccount);

    _mockLiquidationEngine(_oldLiquidationEngine);
    collateralAuctionHouseFactory.addAuthorization(_oldLiquidationEngine);

    if (_oldLiquidationEngine != address(0)) {
      expectEmitNoIndex();
      emit RemoveAuthorization(_oldLiquidationEngine);
    }
    expectEmitNoIndex();
    emit AddAuthorization(_newLiquidationEngine);

    collateralAuctionHouseFactory.modifyParameters('liquidationEngine', abi.encode(_newLiquidationEngine));
  }

  function test_Revert_LiquidationEngine_NullAddress() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAddress.selector);

    collateralAuctionHouseFactory.modifyParameters('liquidationEngine', abi.encode(0));
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
      address(mockCollateralAuctionHouse),
      abi.encodeWithSignature('modifyParameters(bytes32,bytes32,bytes)', _cType, _param, _data),
      1
    );

    collateralAuctionHouseFactory.modifyParameters(_cType, _param, _data);
  }
}
