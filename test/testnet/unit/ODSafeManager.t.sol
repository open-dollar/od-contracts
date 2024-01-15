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
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {Math, RAY} from '@libraries/Math.sol';


  struct Scenario {
    bytes32 cType;
    ISAFEEngine.SAFE safeData;
    ISAFEEngine.SAFEEngineCollateralData cData;
    uint256 coinBalance;
    uint256 collateralBalance;
    int256 deltaCollateral;
    int256 deltaDebt;
    uint256 globalDebt;
    uint256 safeId;
  }

contract Base is HaiTest {
  using stdStorage for StdStorage;
    using Math for uint256;

  address deployer = label('deployer');
  address owner = label('owner');
  address user = address(0xdeadce11);
  address rando = address(0xbeef);
  address userProxy;

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

    userProxy = vault721.build(user);

    vm.stopPrank();
  }

  function _openSafe(bytes32 _cType) internal returns (uint256) {
    return safeManager.openSAFE(_cType, userProxy);
  }

  function _assumeHappyPath(Scenario memory _scenario) internal pure {
    // global
    vm.assume(_scenario.cData.accumulatedRate != 0);

    // modify collateral balance
    vm.assume(notUnderOrOverflowSub(_scenario.collateralBalance, _scenario.deltaCollateral));

    // modify safe collateralization
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.lockedCollateral, _scenario.deltaCollateral));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.generatedDebt, _scenario.deltaDebt));
    uint256 _newLockedCollateral = _scenario.safeData.lockedCollateral.add(_scenario.deltaCollateral);
    uint256 _newSafeDebt = _scenario.safeData.generatedDebt.add(_scenario.deltaDebt);

    // modify collateral debt
    vm.assume(notUnderOrOverflowAdd(_scenario.cData.debtAmount, _scenario.deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_scenario.cData.lockedAmount, _scenario.deltaCollateral));
    uint256 _newCollateralDebt = _scenario.cData.debtAmount.add(_scenario.deltaDebt);

    // modify internal coins (calculates rate adjusted debt)
    vm.assume(notUnderOrOverflowMul(_scenario.cData.accumulatedRate, _scenario.deltaDebt));
    int256 _deltaAdjustedDebt = _scenario.cData.accumulatedRate.mul(_scenario.deltaDebt);
    vm.assume(notUnderOrOverflowAdd(_scenario.coinBalance, _deltaAdjustedDebt));

    // modify globalDebt
    vm.assume(notUnderOrOverflowAdd(_scenario.globalDebt, _deltaAdjustedDebt));

    // --- Safety checks ---

    vm.assume(notOverflowMul(_scenario.cData.accumulatedRate, _newSafeDebt));
    uint256 _totalDebtIssued = _scenario.cData.accumulatedRate * _newSafeDebt;

    // ceilings
    vm.assume(notOverflowMul(_scenario.cData.accumulatedRate, _newCollateralDebt));

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

contract Unit_ODSafeManager_SAFEManagement is Base {

  event OpenSAFE(address indexed _sender, address indexed _own, uint256 indexed _safe);

  modifier happyPath(Scenario memory _scenario){
    _scenario.safeId = _openSafe(_scenario.cType);
    _;
  }

  function test_OpenSafe() public {
    vm.startPrank(user);

    vm.expectEmit(true, true, false, true);

    emit OpenSAFE(user, userProxy, 1);

    uint256 safeId = safeManager.openSAFE('i', userProxy);

    assertEq(safeId, 1, 'incorrect safeId returned');
  }

  event AllowSAFE(address indexed _sender, uint256 indexed _safe, address _usr, bool _ok);

  function test_AllowSafe(Scenario memory _scenario) public happyPath(_scenario){
    vm.startPrank(userProxy);

    vm.expectEmit(true, true, true, true);
    emit AllowSAFE(userProxy, _scenario.safeId, owner, true);

    safeManager.allowSAFE(_scenario.safeId, owner, true);
    uint256[] memory _safes = safeManager.getSafes(userProxy);
    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safes[0], 1, 'incorrect safe id');
  }

  function testAllowSafe_Revert_OnlySafeOwner()public{
    uint256 safeId = _openSafe(collateralTypeA);
    vm.expectRevert(IODSafeManager.OnlySafeOwner.selector);
    safeManager.allowSAFE(safeId, owner, true);
  }

  event TransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);

  function test_transferSAFEOwnership(Scenario memory _scenario) public happyPath(_scenario){
    vm.startPrank(address(vault721));
    vm.expectEmit();
    emit TransferSAFEOwnership(address(vault721), 1, address(user));

    safeManager.transferSAFEOwnership(1, address(user));

    uint256[] memory _safes = safeManager.getSafes(user);
    assertEq(_safes.length, 1, 'SAFE transfer: incorrect number of safes');
    assertEq(_safes[0], 1, 'SAFE transfer: incorrect safe id');
  }

  function test_transferSAFEOwnership_Revert_Vault721() public {
    vm.expectRevert( 'SafeMngr: Only Vault721');
    safeManager.transferSAFEOwnership(1, rando);

  }

  function test_transferSAFEOwnership_Revert_ZeroAddress() public {
    vm.expectRevert(IODSafeManager.ZeroAddress.selector);
    vm.prank(address(vault721));
    safeManager.transferSAFEOwnership(1, address(0));
  }

  function test_transferSAFEOwnership_Revert_AlreadySafeOwner() public {
    vm.prank(userProxy);
    uint256 safeId = _openSafe(collateralTypeA);
    vm.expectRevert(IODSafeManager.AlreadySafeOwner.selector);
    vm.prank(address(vault721));
    safeManager.transferSAFEOwnership(safeId, userProxy);
  }

  event AllowHandler(address indexed _sender, address _usr, bool _ok);

  function test_AllowHandler(Scenario memory _scenario) public happyPath(_scenario){
    vm.startPrank(userProxy);

    vm.expectEmit();
    emit AllowHandler(userProxy, rando, true);

    safeManager.allowHandler(rando, true);

    assertTrue(safeManager.handlerCan(userProxy, rando), 'handler not allowed');
  }
}

contract Unit_ODSafeManager_CollateralManagement is Base {



  modifier happyPath(Scenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _scenario.safeId = _openSafe(_scenario.cType);
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

    vm.prank(userProxy);

    vm.expectEmit();

    emit ModifySAFECollateralization(userProxy, _scenario.safeId, _scenario.deltaCollateral, _scenario.deltaDebt);

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
    vm.prank(userProxy);
    safeManager.allowHandler(safeHandler, true);
    vm.prank(userProxy);
    safeManager.allowSAFE(_scenario.safeId, safeHandler, true);
    vm.mockCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferCollateral.selector), abi.encode());
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    vm.expectEmit();
    emit TransferCollateral(safeHandler, _scenario.safeId, safeHandler, 100);

    vm.prank(safeHandler);
    safeManager.transferCollateral(_scenario.safeId, safeHandler, 100);
  }

  function test_transferCollateral_Revert_HandlerDoesNotExist()public{
    uint256 safeId = _openSafe(collateralTypeA);
    vm.prank(userProxy);
    safeManager.allowSAFE(safeId, rando, true);

    vm.expectRevert(IODSafeManager.HandlerDoesNotExist.selector);
    vm.prank(rando);
    safeManager.transferCollateral(safeId, rando, 100);
  }


  function test_transferCollateral_cType(Scenario memory _scenario) public happyPath(_scenario) {
    vm.mockCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferCollateral.selector), abi.encode());
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.updateVaultHashState.selector), abi.encode());

    vm.expectEmit();
    emit TransferCollateral(userProxy, _scenario.cType, _scenario.safeId, owner, 100);
    vm.prank(userProxy);
    safeManager.transferCollateral(_scenario.cType, _scenario.safeId, owner, 100);
  }

  event TransferInternalCoins(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _rad);

  function test_transferInternalCoins(Scenario memory _scenario) public happyPath(_scenario) {
    vm.expectEmit();
    emit TransferInternalCoins(userProxy, _scenario.safeId, rando, 100);

    vm.mockCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.transferInternalCoins.selector), abi.encode()
    );

    vm.prank(userProxy);
    safeManager.transferInternalCoins(_scenario.safeId, rando, 100);
  }

  function test_addSafe(Scenario memory _scenario) public happyPath(_scenario){
    vm.prank(rando);
    safeManager.addSAFE(_scenario.safeId);
    uint256[] memory _safes = safeManager.getSafes(rando);
    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safes[0], _scenario.safeId, 'incorrect safe id');
  }
}


contract Unit_ODSafeManager_SystemManagement is Base {
    modifier happyPath(Scenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _scenario.safeId = _openSafe(_scenario.cType);
    _;
  }


}