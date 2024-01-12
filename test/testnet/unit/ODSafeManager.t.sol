// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {RAY} from '@libraries/Math.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

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
  SAFEEngine mockSafeEngine;

  function setUp() public virtual {
    ITaxCollector.TaxCollectorParams memory taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: primaryTaxReceiver,
      globalStabilityFee: globalStabilityFee,
      maxStabilityFeeRange: maxStabilityFeeRange,
      maxSecondaryReceivers: 0
    });

    vm.startPrank(deployer);

    mockSafeEngine = SAFEEngine(mockContract('mockSafeEngine'));
    timelockController = TimelockController(payable(mockContract('timeLockController')));

    vault721 = new Vault721();
    taxCollector = new TaxCollector(address(mockSafeEngine), taxCollectorParams);

    taxCollector.addAuthorization(owner);
    vault721.initialize(address(timelockController));

    safeManager = new ODSafeManager(address(mockSafeEngine), address(vault721), address(taxCollector));

    userProxy = vault721.build(user);

    vm.stopPrank();
  }

  function _mockSafeEngineCData(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _lockedAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _liquidationPrice
  ) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.cData, (_cType)),
      abi.encode(_debtAmount, _lockedAmount, _accumulatedRate, _safetyPrice, _liquidationPrice)
    );
  }
  //_mockSafeEngineCData(collateralTypeA, debtAmount, 0, _lastAccumulatedRate, 0, 0);

  function _openSafe(bytes32 _cType) internal returns (uint256) {
    return safeManager.openSAFE(_cType, userProxy);
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
  modifier userSafe(bytes32 _cType) {
    _openSafe(_cType);
    _;
  }

  event OpenSAFE(address indexed _sender, address indexed _own, uint256 indexed _safe);

  function test_OpenSafe() public {
    vm.startPrank(owner);

    vm.expectEmit(true, true, false, true);
    emit OpenSAFE(owner, userProxy, 1);

    uint256 safeId = safeManager.openSAFE('i', userProxy);

    assertEq(safeId, 1, 'incorrect safeId returned');
  }

  event AllowSAFE(address indexed _sender, uint256 indexed _safe, address _usr, bool _ok);

  function test_AllowSafe() public userSafe(collateralTypeA) {
    vm.startPrank(userProxy);

    vm.expectEmit(true, true, true, true);
    emit AllowSAFE(userProxy, 1, owner, true);

    safeManager.allowSAFE(1, owner, true);
    uint256[] memory _safes = safeManager.getSafes(userProxy);
    assertEq(_safes.length, 1, 'incorrect number of safes');
    assertEq(_safes[0], 1, 'incorrect safe id');
  }

  event TransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);

  function test_transferSAFEOwnership() public userSafe(collateralTypeA) {
    vm.startPrank(address(vault721));
    vm.expectEmit();
    emit TransferSAFEOwnership(address(vault721), 1, address(user));

    // note there's no check in the safe manager to make sure you're transferring a safe to a proxy.  only when opening a new safe.

    safeManager.transferSAFEOwnership(1, address(user));

    uint256[] memory _safes = safeManager.getSafes(user);
    assertEq(_safes.length, 1, 'SAFE transfer: incorrect number of safes');
    assertEq(_safes[0], 1, 'SAFE transfer: incorrect safe id');
  }

  event AllowHandler(address indexed _sender, address _usr, bool _ok);

  function test_AllowHandler() public userSafe(collateralTypeA) {
    vm.startPrank(userProxy);

    vm.expectEmit();
    emit AllowHandler(userProxy, rando, true);

    safeManager.allowHandler(rando, true);

    assertTrue(safeManager.handlerCan(userProxy, rando), 'handler not allowed');
  }
}
