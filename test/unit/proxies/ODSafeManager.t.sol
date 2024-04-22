// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ODTest, stdStorage, StdStorage} from '@test/utils/ODTest.t.sol';
import 'forge-std/Vm.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {SAFEEngineForTest, ISAFEEngine} from '@test/mocks/SAFEEngineForTest.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISAFESaviour} from '@interfaces/external/ISAFESaviour.sol';
import {LiquidationEngineForTest} from '@test/mocks/LiquidationEngineForTest.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
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
  address aliceProxy;
  address alice;
  address bob;
}

contract Base is ODTest {
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
  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));

  ILiquidationEngine liquidationEngine;

  ILiquidationEngine.LiquidationEngineParams liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
    onAuctionSystemCoinLimit: type(uint256).max,
    saviourGasLimit: 10_000_000
  });

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
    vault721.initialize(address(timelockController), 0, 0);

    liquidationEngine =
      new LiquidationEngineForTest(address(mockSafeEngine), address(mockAccountingEngine), liquidationEngineParams);

    safeManager =
      new ODSafeManager(address(mockSafeEngine), address(vault721), address(taxCollector), address(liquidationEngine));

    safeManager.addAuthorization(address(this));
    liquidationEngine.addAuthorization(address(this));

    label(address(liquidationEngine), 'LiquidationEngine');
    label(address(safeManager), 'safeManager');
    label(address(taxCollector), 'taxCollector');
    label(address(vault721), 'vault721');
    label(address(mockSafeEngine), 'mockSafeEngine');
    label(address(timelockController), 'timelockController');
    vm.stopPrank();
  }

  function _openSafe(Scenario memory _scenario) internal {
    vm.assume(_scenario.alice != address(0));
    vm.prank(_scenario.alice);
    _scenario.aliceProxy = vault721.build();
    vm.prank(_scenario.alice);
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.mint.selector), abi.encode());
    _scenario.safeId = safeManager.openSAFE(_scenario.cType, _scenario.aliceProxy);
  }

  function _assumeHappyPath(Scenario memory _scenario) internal view {
    // global
    vm.assume(_scenario.cData.accumulatedRate != 0);

    // modify safe collateralization
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.lockedCollateral, _scenario.deltaCollateral));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.generatedDebt, _scenario.deltaDebt));
    vm.assume(_scenario.safeData.generatedDebt < uint256(type(int256).max));
    vm.assume(notUnderOrOverflowMul(_scenario.safeData.lockedCollateral, Math.toInt(_scenario.safeData.generatedDebt)));
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
    vm.assume(_scenario.alice != _scenario.bob);
    address[6] memory addressesToAvoid = [
      address(vault721),
      address(taxCollector),
      address(safeManager),
      address(timelockController),
      address(mockSafeEngine),
      address(_scenario.aliceProxy)
    ];
    for (uint256 i; i < addressesToAvoid.length; i++) {
      vm.assume(_scenario.alice != addressesToAvoid[i]);
      vm.assume(_scenario.bob != addressesToAvoid[i]);
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
    uint256[] memory safes = safeManager.getSafes(_scenario.aliceProxy, _scenario.cType);

    assertEq(safes.length, 1, 'incorrect number of safes');
    assertEq(safes[0], 1, 'incorrect safe id');
  }

  function test_getSafes(Scenario memory _scenario) public happyPath(_scenario) {
    uint256[] memory safes = safeManager.getSafes(_scenario.aliceProxy);

    assertEq(safes.length, 1, 'incorrect number of safes');
    assertEq(safes[0], 1, 'incorrect safe id');
  }

  function test_GetSafesData(Scenario memory _scenario) public happyPath(_scenario) {
    (uint256[] memory _safes, address[] memory _safeHandlers, bytes32[] memory _collateralTypes) =
      safeManager.getSafesData(_scenario.aliceProxy);

    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safeHandlers.length, 1, 'incorrect number of safe handlers');
    assertEq(_collateralTypes.length, 1, 'incorrect number of collateralTypes');
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
    vm.startPrank(_scenario.alice);

    _scenario.aliceProxy = vault721.build(_scenario.alice);

    vm.label(_scenario.aliceProxy, 'Alice Proxy');

    vm.expectEmit(true, true, false, true);
    emit OpenSAFE(_scenario.alice, _scenario.aliceProxy, 1);

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.mint.selector), abi.encode());

    _scenario.safeId = safeManager.openSAFE('i', _scenario.aliceProxy);

    assertEq(_scenario.safeId, 1, 'incorrect safeId returned');
  }

  event AllowSAFE(address indexed _sender, uint256 indexed _safe, address _usr, bool _ok);

  function test_AllowSAFE(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(_scenario.aliceProxy);

    vm.expectEmit();
    emit AllowSAFE(_scenario.aliceProxy, _scenario.safeId, _scenario.bob, true);

    safeManager.allowSAFE(_scenario.safeId, _scenario.bob, true);
    bool safeCan = safeManager.safeCan(_scenario.aliceProxy, _scenario.safeId, 0, _scenario.bob);
    assertTrue(safeCan, 'safe not allowed');
  }

  function test_AllowSafe_Revert_OnlySafeOwner(Scenario memory _scenario) public {
    _openSafe(_scenario);
    vm.expectRevert(IODSafeManager.OnlySafeOwner.selector);
    safeManager.allowSAFE(_scenario.safeId, _scenario.aliceProxy, true);
  }

  event TransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);

  function test_transferSAFEOwnership(Scenario memory _scenario) public happyPath(_scenario) {
    // authorize savior
    ILiquidationEngine saviour = ILiquidationEngine(mockContract('mockSaviour'));

    vm.mockCall(
      address(saviour),
      abi.encodeWithSelector(ISAFESaviour.saveSAFE.selector),
      abi.encode(true, type(uint256).max, type(uint256).max)
    );
    liquidationEngine.connectSAFESaviour(address(saviour));

    //openSafe
    vm.prank(_scenario.bob);
    address bobProxy = vault721.build();
    _scenario.safeId = safeManager.openSAFE(collateralTypeA, bobProxy);

    IODSafeManager.SAFEData memory _sData = safeManager.safeData(_scenario.safeId);

    // protect safe so we can assert that saviour has been cleared
    vm.prank(bobProxy);
    safeManager.protectSAFE(_scenario.safeId, address(saviour));
    assertEq(
      liquidationEngine.chosenSAFESaviour(collateralTypeA, _sData.safeHandler), address(saviour), 'saviour not set'
    );

    vm.expectEmit();
    emit TransferSAFEOwnership(address(vault721), _scenario.safeId, address(_scenario.alice));
    vm.startPrank(address(vault721));
    safeManager.transferSAFEOwnership(_scenario.safeId, address(_scenario.alice));

    uint256[] memory _safes = safeManager.getSafes(_scenario.alice);
    assertEq(_safes.length, 1, 'SAFE transfer: incorrect number of safes');
    assertEq(_safes[0], _scenario.safeId, 'SAFE transfer: incorrect safe id');
    IODSafeManager.SAFEData memory safeData = safeManager.safeData(_scenario.safeId);

    assertEq(safeData.nonce, 1, 'incorrect nonce after transfer');
    assertEq(safeData.owner, _scenario.alice, 'incorrect safe owner');
    assertEq(
      liquidationEngine.chosenSAFESaviour(collateralTypeA, _sData.safeHandler), address(0), 'saviour not cleared'
    );
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
    safeManager.transferSAFEOwnership(_scenario.safeId, _scenario.aliceProxy);
  }

  function test_AddSAFE(Scenario memory _scenario) public happyPath(_scenario) {
    vm.prank(_scenario.bob);
    safeManager.addSAFE(_scenario.safeId);
    uint256[] memory _safes = safeManager.getSafes(_scenario.bob);
    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safes[0], _scenario.safeId, 'incorrect safe id');
  }

  function test_RemoveSAFE(Scenario memory _scenario) public happyPath(_scenario) {
    vm.prank(_scenario.aliceProxy);

    safeManager.removeSAFE(_scenario.safeId);

    uint256[] memory _safes = safeManager.getSafes(_scenario.bob);
    assertEq(_safes.length, 0, 'incorrect number of safes');
  }

  event MoveSAFE(address indexed _sender, uint256 indexed _safeSrc, uint256 indexed _safeDst);

  function test_MoveSAFE(Scenario memory _scenario) public happyPath(_scenario) {
    address newaliceProxy = vault721.build(_scenario.bob);
    vm.prank(newaliceProxy);
    uint256 safeId2 = safeManager.openSAFE(_scenario.cType, newaliceProxy);

    vm.prank(newaliceProxy);
    safeManager.allowSAFE(safeId2, _scenario.aliceProxy, true);

    vm.expectEmit();
    emit MoveSAFE(address(_scenario.aliceProxy), _scenario.safeId, safeId2);

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector), abi.encode(_scenario.safeData)
    );

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferSAFECollateralAndDebt.selector), abi.encode()
    );

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateNfvState.selector), abi.encode());

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateNfvState.selector), abi.encode());

    vm.prank(_scenario.aliceProxy);
    safeManager.moveSAFE(_scenario.safeId, safeId2);
  }

  event ProtectSAFE(address indexed _sender, uint256 indexed _safe, address _liquidationEngine, address _saviour);

  function test_ProtectSafe(Scenario memory _scenario) public happyPath(_scenario) {
    ILiquidationEngine saviour = ILiquidationEngine(mockContract('mockSaviour'));

    vm.mockCall(
      address(saviour),
      abi.encodeWithSelector(ISAFESaviour.saveSAFE.selector),
      abi.encode(true, type(uint256).max, type(uint256).max)
    );
    liquidationEngine.connectSAFESaviour(address(saviour));

    //openSafe
    vm.prank(_scenario.bob);
    address bobProxy = vault721.build();
    _scenario.safeId = safeManager.openSAFE(collateralTypeA, bobProxy);

    IODSafeManager.SAFEData memory _sData = safeManager.safeData(_scenario.safeId);

    // protect safe so we can assert that saviour has been cleared
    vm.prank(bobProxy);

    vm.expectEmit();
    emit ProtectSAFE(bobProxy, _scenario.safeId, address(liquidationEngine), address(saviour));
    safeManager.protectSAFE(_scenario.safeId, address(saviour));

    assertEq(
      liquidationEngine.chosenSAFESaviour(collateralTypeA, _sData.safeHandler), address(saviour), 'saviour not set'
    );

    vm.prank(bobProxy);
    safeManager.protectSAFE(_scenario.safeId, address(saviour));
  }
}

contract Unit_ODSafeManager_SystemManagement is Base {
  modifier happyPath(Scenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _openSafe(_scenario);
    _;
  }

  function test_QuitSystem(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(_scenario.aliceProxy);
    safeManager.allowSAFE(_scenario.safeId, _scenario.aliceProxy, true);

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferSAFECollateralAndDebt.selector), abi.encode()
    );

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateNfvState.selector), abi.encode());

    safeManager.quitSystem(_scenario.safeId);
  }
}

import 'forge-std/console2.sol';

contract Unit_ODSafeManager_CollateralManagement is Base {
  modifier happyPath(Scenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _openSafe(_scenario);
    _;
  }

  event ModifySAFECollateralization(
    address indexed _sender, uint256 indexed _safe, int256 _deltaCollateral, int256 _deltaDebt
  );
  event NFVStateUpdated(uint256 _safeId);

  function test_modifySAFECollateralization(Scenario memory _scenario) public happyPath(_scenario) {
    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.modifySAFECollateralization.selector), abi.encode()
    );

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.updateAccumulatedRate.selector), abi.encode()
    );

    vm.mockCall(
      address(taxCollector),
      abi.encodeWithSelector(ITaxCollector.taxSingle.selector),
      abi.encode(_scenario.cData.accumulatedRate)
    );

    vm.expectEmit();
    emit ModifySAFECollateralization(
      _scenario.aliceProxy, _scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt
    );
    vm.prank(_scenario.aliceProxy);
    safeManager.modifySAFECollateralization(_scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt, true);
  }

  function test_modifySAFECollateralization_NoUpdateNFVState(Scenario memory _scenario) public happyPath(_scenario) {
    _scenario.deltaCollateral = 0;
    _scenario.deltaDebt = 0;
    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.modifySAFECollateralization.selector), abi.encode()
    );

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.updateAccumulatedRate.selector), abi.encode()
    );

    vm.mockCall(
      address(taxCollector),
      abi.encodeWithSelector(ITaxCollector.taxSingle.selector),
      abi.encode(_scenario.cData.accumulatedRate)
    );

    vm.expectEmit();
    emit ModifySAFECollateralization(
      _scenario.aliceProxy, _scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    vm.prank(_scenario.aliceProxy);
    vm.recordLogs();
    safeManager.modifySAFECollateralization(_scenario.safeId, (_scenario.deltaCollateral), (_scenario.deltaDebt), true);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bool modifySafeLog = false;
    bool nfvStateLog = false;
    for (uint256 i; i < entries.length; i++) {
      if (entries[i].topics[0] == keccak256('ModifySAFECollateralization(address,uint256,int256,int256)')) {
        modifySafeLog = true;
      }
      if (entries[i].topics[0] == keccak256('NFVStateUpdated(uint256)')) nfvStateLog = true;
    }
    assertTrue(modifySafeLog);
    assertFalse(nfvStateLog);
  }

  function test_modifySAFECollateralization_UpdateNFVState(Scenario memory _scenario) public happyPath(_scenario) {
    _scenario.deltaCollateral = -100;
    _scenario.deltaDebt = 100;

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.modifySAFECollateralization.selector), abi.encode()
    );

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.updateAccumulatedRate.selector), abi.encode()
    );

    vm.mockCall(
      address(taxCollector),
      abi.encodeWithSelector(ITaxCollector.taxSingle.selector),
      abi.encode(_scenario.cData.accumulatedRate)
    );

    vm.expectEmit();
    emit ModifySAFECollateralization(
      _scenario.aliceProxy, _scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt
    );
    vm.prank(_scenario.aliceProxy);
    vm.recordLogs();
    safeManager.modifySAFECollateralization(_scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt, true);

    Vm.Log[] memory entries = vm.getRecordedLogs();

    bool modifySafeLog = false;
    bool nfvStateLog = false;
    for (uint256 i; i < entries.length; i++) {
      if (entries[i].topics[0] == keccak256('ModifySAFECollateralization(address,uint256,int256,int256)')) {
        modifySafeLog = true;
      }
      if (entries[i].topics[0] == keccak256('NFVStateUpdated(uint256)')) nfvStateLog = true;
    }

    assertTrue(modifySafeLog);
    assertTrue(nfvStateLog);
  }

  function test_modifySAFECollateralization_Revert_SafeNotAllowed(Scenario memory _scenario) public {
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    safeManager.modifySAFECollateralization(_scenario.safeId, (_scenario.deltaCollateral), (_scenario.deltaDebt), true);
  }

  function test_SafeAllowed(Scenario memory _scenario) public happyPath(_scenario) {
    _scenario.bob = address(45_667);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    vm.prank(_scenario.bob);
    safeManager.modifySAFECollateralization(_scenario.safeId, (_scenario.deltaCollateral), (_scenario.deltaDebt), true);

    vm.prank(_scenario.aliceProxy);
    safeManager.allowSAFE(_scenario.safeId, _scenario.bob, true);

    // mock external calls
    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.modifySAFECollateralization.selector), abi.encode()
    );

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(mockSafeEngine.updateAccumulatedRate.selector), abi.encode()
    );

    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateNfvState.selector), abi.encode());

    vm.mockCall(
      address(taxCollector),
      abi.encodeWithSelector(ITaxCollector.taxSingle.selector),
      abi.encode(_scenario.cData.accumulatedRate)
    );

    vm.expectEmit();

    emit ModifySAFECollateralization(_scenario.bob, _scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt);

    vm.prank(_scenario.bob);
    safeManager.modifySAFECollateralization(_scenario.safeId, (_scenario.deltaCollateral), (_scenario.deltaDebt), true);
  }

  event TransferCollateral(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _wad);

  event TransferCollateral(address indexed _sender, bytes32 _cType, uint256 indexed _safe, address _dst, uint256 _wad);

  function test_transferCollateral(Scenario memory _scenario) public happyPath(_scenario) {
    vm.mockCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferCollateral.selector), abi.encode());
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateNfvState.selector), abi.encode());

    vm.expectEmit();
    emit TransferCollateral(_scenario.aliceProxy, _scenario.safeId, _scenario.aliceProxy, 100);

    vm.prank(_scenario.aliceProxy);
    safeManager.transferCollateral(_scenario.safeId, _scenario.aliceProxy, 100);
  }

  function test_transferCollateral_cType(Scenario memory _scenario) public happyPath(_scenario) {
    vm.mockCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferCollateral.selector), abi.encode());
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateNfvState.selector), abi.encode());

    vm.expectEmit();
    emit TransferCollateral(_scenario.aliceProxy, _scenario.cType, _scenario.safeId, owner, 100);
    vm.prank(_scenario.aliceProxy);
    safeManager.transferCollateral(_scenario.cType, _scenario.safeId, owner, 100);
  }

  event TransferInternalCoins(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _rad);

  function test_transferInternalCoins(Scenario memory _scenario) public happyPath(_scenario) {
    vm.expectEmit();
    emit TransferInternalCoins(_scenario.aliceProxy, _scenario.safeId, _scenario.bob, 100);

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferInternalCoins.selector), abi.encode()
    );

    vm.prank(_scenario.aliceProxy);
    safeManager.transferInternalCoins(_scenario.safeId, _scenario.bob, 100);
  }
}

contract Unit_ODSafeManager_ModifyParameters is Base {
  function test_ModifyParameters_LiquidationEngine() public {
    safeManager.modifyParameters('liquidationEngine', abi.encode(address(1)));
    assertEq(safeManager.liquidationEngine(), address(1));
  }

  function test_ModifyParameters_TaxCollector() public {
    safeManager.modifyParameters('taxCollector', abi.encode(address(1)));
    assertEq(safeManager.taxCollector(), address(1));
  }

  function test_ModifyParameters_Vault721() public {
    safeManager.modifyParameters('vault721', abi.encode(address(1)));
    assertEq(address(safeManager.vault721()), address(1));
  }

  function test_ModifyParameters_SafeEngine() public {
    safeManager.modifyParameters('safeEngine', abi.encode(address(1)));
    assertEq(safeManager.safeEngine(), address(1));
  }

  function test_ModifyParameters_Revert_UnrecognizedParam() public {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    safeManager.modifyParameters('unrecognizedParam', abi.encode(address(1)));
  }
}
