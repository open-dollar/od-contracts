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

  function _mockCollateralAuctionHouse(bytes32 _cType, address _collateralAuctionHouse) internal {
    collateralAuctionHouseFactory.addCollateralAuctionHouse(_cType, _collateralAuctionHouse);
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

  function test_Revert_RepeatedCType(bytes32 _cType) public happyPath {
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

  function test_Set_CollateralTypes(bytes32 _cType) public happyPath {
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(_cType, _cahCParams);

    assertEq(collateralAuctionHouseFactory.collateralTypesList()[0], _cType);
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
