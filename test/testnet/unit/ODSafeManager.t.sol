// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {SAFEEngineForTest, ISAFEEngine} from '@testnet/mocks/SAFEEngineForTest.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {Math, RAY} from '@libraries/Math.sol';

struct Scenario {
  bytes32 cType;
  ISAFEEngine.SAFE safeData;
  ISAFEEngine.SAFEEngineCollateralData cData;
  int256 deltaCollateral;
  int256 deltaDebt;
  uint256 safeId;
  address userProxy;
  address user;
  address rando;
}

contract Base is HaiTest {
  using stdStorage for StdStorage;
  using Math for uint256;

  address deployer = label('deployer');
  address owner = label('owner');

  //tax collector params
  address primaryTaxReceiver = newAddress();
  uint256 globalStabilityFee = RAY;
  uint256 maxStabilityFeeRange = RAY - 1;

  // SafeEngine storage
  bytes32 collateralTypeA = 'collateralTypeA';
  uint256 debtAmount = 1e25;
  uint256 lastAccumulatedRate = 1e15;

  Vault721 vault721;
  TaxCollector taxCollector;
  ODSafeManager safeManager;
  TimelockController timelockController;
  ISAFEEngine mockSafeEngine;

  function setUp() public virtual {
    ITaxCollector.TaxCollectorParams memory taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: primaryTaxReceiver,
      globalStabilityFee: globalStabilityFee,
      maxStabilityFeeRange: maxStabilityFeeRange,
      maxSecondaryReceivers: 0
    });

    ISAFEEngine.SAFEEngineParams memory safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 1e18});

    vm.startPrank(deployer);

    mockSafeEngine = new SAFEEngineForTest(safeEngineParams);
    timelockController = TimelockController(payable(mockContract('timeLockController')));

    vault721 = new Vault721();
    taxCollector = new TaxCollector(address(mockSafeEngine), taxCollectorParams);

    taxCollector.addAuthorization(owner);
    vault721.initialize(address(timelockController));

    safeManager = new ODSafeManager(address(mockSafeEngine), address(vault721), address(taxCollector));

    vm.stopPrank();
  }

  function _openSafe(Scenario memory _scenario) internal {
    vm.assume(_scenario.user != address(0));
    vm.prank(_scenario.user);
    _scenario.userProxy = vault721.build();
    vm.prank(_scenario.userProxy);
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.mint.selector), abi.encode());
    _scenario.safeId = safeManager.openSAFE(_scenario.cType, _scenario.userProxy);
  }

  function _assumeHappyPath(Scenario memory _scenario) internal pure {
    // global
    vm.assume(_scenario.cData.accumulatedRate != 0);

    // modify safe collateralization
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.lockedCollateral, _scenario.deltaCollateral));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.generatedDebt, _scenario.deltaDebt));
    uint256 _newLockedCollateral = _scenario.safeData.lockedCollateral.add(_scenario.deltaCollateral);
    uint256 _newSafeDebt = _scenario.safeData.generatedDebt.add(_scenario.deltaDebt);

    // modify collateral debt
    vm.assume(notUnderOrOverflowAdd(_scenario.cData.debtAmount, _scenario.deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_scenario.cData.lockedAmount, _scenario.deltaCollateral));

    // modify internal coins (calculates rate adjusted debt)
    vm.assume(notUnderOrOverflowMul(_scenario.cData.accumulatedRate, _scenario.deltaDebt));

    // --- Safety checks ---

    vm.assume(notOverflowMul(_scenario.cData.accumulatedRate, _newSafeDebt));
    uint256 _totalDebtIssued = _scenario.cData.accumulatedRate * _newSafeDebt;

    // safety
    vm.assume(notOverflowMul(_scenario.cData.accumulatedRate, _newSafeDebt));
    vm.assume(notOverflowMul(_newLockedCollateral, _scenario.cData.safetyPrice));
    if (_scenario.deltaDebt > 0 || _scenario.deltaCollateral < 0) {
      vm.assume(_totalDebtIssued <= _newLockedCollateral * _scenario.cData.safetyPrice);
    }
  }
}

contract Unit_ODSafeManager_Deployment is Base {
  function testDeployment() public {
    assertEq(address(safeManager.vault721()), address(vault721), 'incorrect vault721');
    assertEq(safeManager.safeEngine(), address(mockSafeEngine), 'incorrect safe engine');
    assertEq(safeManager.taxCollector(), address(taxCollector), 'incorrect tax collector');
  }
}

contract Unit_ODSafeManager_ViewFunctions is Base {
  modifier happyPath(Scenario memory _scenario) {
    _openSafe(_scenario);
    _;
  }

  function test_getSafes_PerCollateral(Scenario memory _scenario) public happyPath(_scenario) {
    uint256[] memory safes = safeManager.getSafes(_scenario.userProxy, _scenario.cType);

    assertEq(safes.length, 1, 'incorrect number of safes');
    assertEq(safes[0], 1, 'incorrect safe id');
  }

  function test_getSafes(Scenario memory _scenario) public happyPath(_scenario) {
    uint256[] memory safes = safeManager.getSafes(_scenario.userProxy);

    assertEq(safes.length, 1, 'incorrect number of safes');
    assertEq(safes[0], 1, 'incorrect safe id');
  }

  function test_GetSafesData(Scenario memory _scenario) public happyPath(_scenario) {
    (uint256[] memory _safes, address[] memory _safeHandlers, bytes32[] memory _cTypes) =
      safeManager.getSafesData(_scenario.userProxy);

    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safeHandlers.length, 1, 'incorrect number of safe handlers');
    assertEq(_cTypes.length, 1, 'incorrect number of cTypes');
  }
}

contract Unit_ODSafeManager_SAFEManagement is Base {
  event OpenSAFE(address indexed _sender, address indexed _own, uint256 indexed _safe);

  modifier happyPath(Scenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _openSafe(_scenario);
    _;
  }

  function test_OpenSafe(Scenario memory _scenario) public {
    vm.startPrank(_scenario.user);

    _scenario.userProxy = vault721.build(_scenario.user);

    vm.expectEmit(true, true, false, true);

    emit OpenSAFE(_scenario.user, _scenario.userProxy, 1);

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.mint.selector), abi.encode());

    _scenario.safeId = safeManager.openSAFE('i', _scenario.userProxy);

    assertEq(_scenario.safeId, 1, 'incorrect safeId returned');
  }

  event AllowSAFE(address indexed _sender, uint256 indexed _safe, address _usr, bool _ok);

  function test_AllowSafe(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(_scenario.userProxy);

    vm.expectEmit();
    emit AllowSAFE(_scenario.userProxy, _scenario.safeId, owner, true);

    safeManager.allowSAFE(_scenario.safeId, owner, true);
    uint256[] memory _safes = safeManager.getSafes(_scenario.userProxy);
    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safes[0], 1, 'incorrect safe id');
  }

  function test_AllowSafe_Revert_OnlySafeOwner(Scenario memory _scenario) public {
    _openSafe(_scenario);
    vm.expectRevert(IODSafeManager.OnlySafeOwner.selector);
    safeManager.allowSAFE(_scenario.safeId, _scenario.userProxy, true);
  }

  event TransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);

  function test_transferSAFEOwnership(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(address(vault721));
    vm.expectEmit();

    emit TransferSAFEOwnership(address(vault721), 1, address(_scenario.user));

    safeManager.transferSAFEOwnership(1, address(_scenario.user));

    uint256[] memory _safes = safeManager.getSafes(_scenario.user);
    assertEq(_safes.length, 1, 'SAFE transfer: incorrect number of safes');
    assertEq(_safes[0], 1, 'SAFE transfer: incorrect safe id');
  }

  function test_transferSAFEOwnership_Revert_Vault721() public {
    vm.expectRevert('SafeMngr: Only Vault721');
    safeManager.transferSAFEOwnership(1, address(0x6));
  }

  function test_transferSAFEOwnership_Revert_ZeroAddress() public {
    vm.expectRevert(IODSafeManager.ZeroAddress.selector);
    vm.prank(address(vault721));
    safeManager.transferSAFEOwnership(1, address(0));
  }

  function test_transferSAFEOwnership_Revert_AlreadySafeOwner(Scenario memory _scenario) public {
    _openSafe(_scenario);
    vm.expectRevert(IODSafeManager.AlreadySafeOwner.selector);
    vm.prank(address(vault721));
    safeManager.transferSAFEOwnership(_scenario.safeId, _scenario.userProxy);
  }

  event AllowHandler(address indexed _sender, address _usr, bool _ok);

  function test_AllowHandler(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(_scenario.userProxy);

    vm.expectEmit();
    emit AllowHandler(_scenario.userProxy, _scenario.rando, true);

    safeManager.allowHandler(_scenario.rando, true);

    assertTrue(safeManager.handlerCan(_scenario.userProxy, _scenario.rando), 'handler not allowed');
  }

  function test_AddSAFE(Scenario memory _scenario) public happyPath(_scenario) {
    vm.prank(_scenario.rando);
    safeManager.addSAFE(_scenario.safeId);
    uint256[] memory _safes = safeManager.getSafes(_scenario.rando);
    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safes[0], _scenario.safeId, 'incorrect safe id');
  }

  function test_RemoveSAFE(Scenario memory _scenario) public happyPath(_scenario) {
    vm.prank(_scenario.userProxy);

    safeManager.removeSAFE(_scenario.safeId);

    uint256[] memory _safes = safeManager.getSafes(_scenario.rando);
    assertEq(_safes.length, 0, 'incorrect number of safes');
  }

  event MoveSAFE(address indexed _sender, uint256 indexed _safeSrc, uint256 indexed _safeDst);

  function test_MoveSAFE(Scenario memory _scenario) public happyPath(_scenario) {
    address newUserProxy = vault721.build(_scenario.rando);
    vm.prank(newUserProxy);
    uint256 safeId2 = safeManager.openSAFE(_scenario.cType, newUserProxy);

    vm.prank(newUserProxy);
    safeManager.allowSAFE(safeId2, _scenario.userProxy, true);

    vm.expectEmit();
    emit MoveSAFE(address(_scenario.userProxy), _scenario.safeId, safeId2);

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector), abi.encode(_scenario.safeData)
    );

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferSAFECollateralAndDebt.selector), abi.encode()
    );

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    vm.prank(_scenario.userProxy);
    safeManager.moveSAFE(_scenario.safeId, safeId2);
  }

  event ProtectSAFE(address indexed _sender, uint256 indexed _safe, address _liquidationEngine, address _saviour);

  function test_ProtectSafe(Scenario memory _scenario) public happyPath(_scenario) {
    address mockLiquidationEngine = address(0xc0ffee);
    address mockSavior = address(0x1337);
    vm.expectEmit();
    emit ProtectSAFE(_scenario.userProxy, _scenario.safeId, mockLiquidationEngine, mockSavior);

    vm.mockCall(
      address(mockLiquidationEngine), abi.encodeWithSelector(ILiquidationEngine.protectSAFE.selector), abi.encode()
    );

    vm.prank(_scenario.userProxy);
    safeManager.protectSAFE(_scenario.safeId, mockLiquidationEngine, mockSavior);
  }
}

contract Unit_ODSafeManager_SystemManagement is Base {
  modifier happyPath(Scenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _openSafe(_scenario);
    _;
  }

  function test_EnterSystem(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(_scenario.userProxy);
    safeManager.allowHandler(_scenario.userProxy, true);
    safeManager.allowSAFE(_scenario.safeId, _scenario.userProxy, true);
    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferSAFECollateralAndDebt.selector), abi.encode()
    );

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    safeManager.enterSystem(_scenario.userProxy, _scenario.safeId);
  }

  function test_QuitSystem(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(_scenario.userProxy);
    safeManager.allowHandler(_scenario.userProxy, true);
    safeManager.allowSAFE(_scenario.safeId, _scenario.userProxy, true);

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferSAFECollateralAndDebt.selector), abi.encode()
    );

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    safeManager.quitSystem(_scenario.safeId, _scenario.userProxy);
  }
}

contract Unit_ODSafeManager_CollateralManagement is Base {
  modifier happyPath(Scenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _openSafe(_scenario);
    _;
  }

  event ModifySAFECollateralization(
    address indexed _sender, uint256 indexed _safe, int256 _deltaCollateral, int256 _deltaDebt
  );

  function test_modifySAFECollateralization(Scenario memory _scenario) public happyPath(_scenario) {
    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.modifySAFECollateralization.selector), abi.encode()
    );

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.updateAccumulatedRate.selector), abi.encode()
    );

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    vm.mockCall(
      address(taxCollector),
      abi.encodeWithSelector(ITaxCollector.taxSingle.selector),
      abi.encode(_scenario.cData.accumulatedRate)
    );

    vm.prank(_scenario.userProxy);

    vm.expectEmit();

    emit ModifySAFECollateralization(
      _scenario.userProxy, _scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    safeManager.modifySAFECollateralization(_scenario.safeId, (_scenario.deltaCollateral), (_scenario.deltaDebt), true);
  }

  function test_modifySAFECollateralization_Revert_SafeNotAllowed(Scenario memory _scenario) public {
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    safeManager.modifySAFECollateralization(_scenario.safeId, (_scenario.deltaCollateral), (_scenario.deltaDebt), true);
  }

  event TransferCollateral(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _wad);

  event TransferCollateral(address indexed _sender, bytes32 _cType, uint256 indexed _safe, address _dst, uint256 _wad);

  function test_transferCollateral(Scenario memory _scenario) public happyPath(_scenario) {
    address safeHandler = safeManager.safeData(_scenario.safeId).safeHandler;
    vm.prank(_scenario.userProxy);
    safeManager.allowHandler(safeHandler, true);
    vm.prank(_scenario.userProxy);
    safeManager.allowSAFE(_scenario.safeId, safeHandler, true);
    vm.mockCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferCollateral.selector), abi.encode());
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    vm.expectEmit();
    emit TransferCollateral(safeHandler, _scenario.safeId, safeHandler, 100);

    vm.prank(safeHandler);
    safeManager.transferCollateral(_scenario.safeId, safeHandler, 100);
  }

  function test_transferCollateral_Revert_HandlerDoesNotExist(Scenario memory _scenario) public {
    _openSafe(_scenario);
    vm.prank(_scenario.userProxy);
    safeManager.allowSAFE(_scenario.safeId, _scenario.rando, true);

    vm.expectRevert(IODSafeManager.HandlerDoesNotExist.selector);
    vm.prank(_scenario.rando);
    safeManager.transferCollateral(_scenario.safeId, _scenario.rando, 100);
  }

  function test_transferCollateral_cType(Scenario memory _scenario) public happyPath(_scenario) {
    vm.mockCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferCollateral.selector), abi.encode());
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    vm.expectEmit();
    emit TransferCollateral(_scenario.userProxy, _scenario.cType, _scenario.safeId, owner, 100);
    vm.prank(_scenario.userProxy);
    safeManager.transferCollateral(_scenario.cType, _scenario.safeId, owner, 100);
  }

  event TransferInternalCoins(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _rad);

  function test_transferInternalCoins(Scenario memory _scenario) public happyPath(_scenario) {
    vm.expectEmit();
    emit TransferInternalCoins(_scenario.userProxy, _scenario.safeId, _scenario.rando, 100);

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferInternalCoins.selector), abi.encode()
    );

    vm.prank(_scenario.userProxy);
    safeManager.transferInternalCoins(_scenario.safeId, _scenario.rando, 100);
  }
}