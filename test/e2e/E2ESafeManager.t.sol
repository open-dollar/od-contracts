// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, TKN, RAY, COLLAT, DEBT} from './Common.t.sol';
import {Base_CType} from '@test/scopes/Base_CType.t.sol';
import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {SafeSaviourForForTest} from '@test/mocks/SafeSaviourForTest.sol';

import {HOUR, YEAR, RAD, WAD, RAY} from '@libraries/Math.sol';

import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {Assertions} from '@libraries/Assertions.sol';

import 'forge-std/console2.sol';

abstract contract BasicActionsForE2ETests is Common {
  function depositCollatAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function genDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.generateDebt.selector, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function allowSafe(address _proxy, uint256 _safeId, address _user, bool _ok) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.allowSAFE.selector, address(safeManager), _safeId, _user, _ok);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function quitSystem(address _proxy, uint256 _safeId) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.quitSystem.selector, address(safeManager), _safeId);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function moveSAFE(address _proxy, uint256 _src, uint256 _dst) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.moveSAFE.selector, address(safeManager), _src, _dst);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function addSAFE(address _proxy, uint256 _safe) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.addSAFE.selector, address(safeManager), _safe);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function removeSAFE(address _proxy, uint256 _safe) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.removeSAFE.selector, address(safeManager), _safe);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function protectSAFE(address _proxy, uint256 _safe, address _liquidationEngine, address _saviour) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.protectSAFE.selector, address(safeManager), _safe, _liquidationEngine, _saviour
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function modifySAFECollateralization(
    address _proxy,
    uint256 _safeId,
    int256 _collateralDelta,
    int256 _debtDelta
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.modifySAFECollateralization.selector, address(safeManager), _safeId, _collateralDelta, _debtDelta
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function modifySAFECollateralizationNonHandler(
    address _proxy,
    uint256 _safeId,
    int256 _collateralDelta,
    int256 _debtDelta
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.modifySAFECollateralizationNonSafeHandler.selector,
      address(safeManager),
      _safeId,
      _collateralDelta,
      _debtDelta
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function freeTokenCollateral(address _proxy, bytes32 _cType, uint256 _safeId, uint256 _deltaWad) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.freeTokenCollateral.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      _safeId,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function transferCollateral(address _proxy, uint256 _safeId, address _dst, uint256 _deltaWad) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.transferCollateral.selector, address(safeManager), _safeId, _dst, _deltaWad);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function transferInternalCoins(address _proxy, uint256 _safeId, address _dst, uint256 _rad) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.transferInternalCoins.selector, address(safeManager), _safeId, _dst, _rad);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function repayDebt(uint256 _safeId, uint256 _deltaWad, address proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.repayDebt.selector, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );
    ODProxy(proxy).execute(address(basicActions), payload);
  }

  function repayAllDebt(uint256 _safeId, address proxy) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.repayAllDebt.selector, address(safeManager), address(coinJoin), _safeId);
    ODProxy(proxy).execute(address(basicActions), payload);
  }

  function openSafe() public returns (uint256 safeId, address proxy) {
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), TKN, proxy);
    bytes memory safeData = ODProxy(proxy).execute(address(basicActions), payload);
    safeId = abi.decode(safeData, (uint256));
  }
}

abstract contract E2ESafeManagerSetUp is Base_CType, BasicActionsForE2ETests {
  address aliceProxy;
  address bobProxy;

  uint256 aliceSafeId;
  uint256 bobSafeId;

  IODSafeManager.SAFEData public aliceData;
  IODSafeManager.SAFEData public bobData;

  ERC20ForTest internal _token;

  event NFVStateUpdated(uint256 _vaultId);

  function setUp() public virtual override {
    super.setUp();
    super.setupEnvironment();
    aliceProxy = deployOrFind(alice);
    aliceSafeId = safeManager.openSAFE(_cType(), aliceProxy);
    aliceData = safeManager.safeData(aliceSafeId);

    //mint collateral to alice
    _token = ERC20ForTest(address(ICollateralJoin(address(collateralJoin[_cType()])).collateral()));
    vm.prank(alice);
    _token.approve(address(aliceProxy), type(uint256).max);
  }

  function deployOrFind(address owner) public returns (address payable) {
    address proxy = vault721.getProxy(owner);
    if (proxy == address(0)) {
      return vault721.build(owner);
    } else {
      return payable(address(proxy));
    }
  }

  function _cType() internal pure override returns (bytes32) {
    return TKN;
  }

  function _removeDelays() internal {
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters('timeDelay', abi.encode(0 days));
    vault721.modifyParameters('blockDelay', abi.encode(0));
    vm.stopPrank();
  }
}

contract E2ESafeManagerTest_ViewFunctions is E2ESafeManagerSetUp {
  function test_GetSafes() public view {
    uint256[] memory safes = safeManager.getSafes(address(aliceProxy));
    assertEq(safes.length, 1);
  }

  function test_GetSafes_Ctype() public view {
    uint256[] memory safes = safeManager.getSafes(aliceProxy, _cType());
    assertEq(safes.length, 1);
  }

  function test_GetSafesData() public view {
    (uint256[] memory _safes, address[] memory _safeHandlers, bytes32[] memory _cTypes) =
      safeManager.getSafesData(aliceProxy);
    assertEq(_safes.length, 1);
    assertEq(_safeHandlers.length, 1);
    assertEq(_cTypes.length, 1);
  }

  function test_GetSafeDataFromHandler() public view {
    IODSafeManager.SAFEData memory _data = safeManager.getSafeDataFromHandler(aliceData.safeHandler);

    assertEq(_data.nonce, 0);
    assertEq(_data.owner, aliceProxy);
    assertEq(_data.collateralType, _cType());
    assertEq(_data.safeHandler, aliceData.safeHandler);
  }

  function test_SafeData() public view {
    IODSafeManager.SAFEData memory _data = safeManager.safeData(aliceSafeId);
    assertEq(_data.nonce, 0);
    assertEq(_data.owner, aliceProxy);
    assertEq(_data.collateralType, _cType());
    assertEq(_data.safeHandler, aliceData.safeHandler);
  }

  function test_AllowSafe() public {
    vm.prank(alice);
    assertFalse(safeManager.safeCan(aliceProxy, aliceSafeId, 0, alice));
    vm.prank(aliceProxy);
    safeManager.allowSAFE(aliceSafeId, alice, true);

    vm.prank(alice);
    assertTrue(safeManager.safeCan(aliceProxy, aliceSafeId, 0, alice));
  }

  function test_OpenSafe() public {
    bobProxy = deployOrFind(bob);
    vm.prank(bobProxy);
    bobSafeId = safeManager.openSAFE(_cType(), bobProxy);
    assertEq(safeManager.getSafes(bobProxy).length, 1);
    assertEq(vault721.ownerOf(bobSafeId), bob);
  }
}

contract E2ESafeManagerTest_TransferOwnership is E2ESafeManagerSetUp {
  event TransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);

  address testSaviour;

  function setUp() public override {
    super.setUp();
    testSaviour = address(new SafeSaviourForForTest());
    vm.prank(address(timelockController));
    liquidationEngine.connectSAFESaviour(testSaviour);
  }

  function test_TransferSafeOwnership() public {
    bobProxy = deployOrFind(bob);
    //set safe savior to test savior clearing on transfer
    vm.prank(aliceProxy);
    safeManager.protectSAFE(aliceSafeId, testSaviour);
    assertEq(liquidationEngine.chosenSAFESaviour(_cType(), aliceData.safeHandler), testSaviour);

    _removeDelays();
    vm.startPrank(alice);
    vm.expectEmit(address(safeManager));
    emit TransferSAFEOwnership(address(vault721), aliceSafeId, bobProxy);
    vault721.transferFrom(alice, bob, aliceSafeId);
    vm.stopPrank();

    aliceData = safeManager.safeData(aliceSafeId);

    assertEq(liquidationEngine.chosenSAFESaviour(_cType(), aliceData.safeHandler), address(0));
    assertEq(vault721.ownerOf(aliceSafeId), bob);
    assertEq(aliceData.nonce, 1);
    assertEq(safeManager.getSafes(aliceProxy).length, 0);
    assertEq(safeManager.getSafes(bobProxy).length, 1);
    assertEq(safeManager.getSafes(aliceProxy, _cType()).length, 0);
    assertEq(safeManager.getSafes(bobProxy, _cType()).length, 1);
    assertEq(aliceData.owner, bobProxy);
  }

  function test_TransferSafeOwnership_Revert_ZeroAddress() public {
    _removeDelays();

    vm.expectRevert(IODSafeManager.ZeroAddress.selector);
    vm.startPrank(address(vault721));
    safeManager.transferSAFEOwnership(aliceSafeId, address(0));
    vm.stopPrank();
  }

  function test_TransferSafeOwnership_Revert_Vault721Only() public {
    _removeDelays();

    vm.expectRevert('SafeMngr: Only Vault721');
    vm.startPrank(alice);
    safeManager.transferSAFEOwnership(aliceSafeId, address(0));
    vm.stopPrank();
  }

  function test_TransferSafeOwnership_Revert_AlreadySafeOwner() public {
    _removeDelays();

    vm.expectRevert(IODSafeManager.AlreadySafeOwner.selector);
    vm.startPrank(alice);
    vault721.transferFrom(alice, alice, aliceSafeId);
    vm.stopPrank();
  }
}

contract E2ESafeManagerTest_ModifySafeCollateralization is E2ESafeManagerSetUp {
  struct Scenario {
    uint256 mintedCollateral;
    uint256 generatedDebt;
    uint256 lockedCollateral;
  }

  modifier happyPath(Scenario memory _scenario) {
    ISAFEEngine.SAFEEngineCollateralParams memory safeEngineParams = safeEngine.cParams(_cType());
    ISAFEEngine.SAFEEngineCollateralData memory cData = safeEngine.cData(_cType());
    vm.assume(notOverflowMul(_scenario.mintedCollateral, cData.accumulatedRate));
    vm.assume(
      _scenario.mintedCollateral > 10_000
        && _scenario.mintedCollateral * cData.accumulatedRate < safeEngineParams.debtCeiling
    );
    vm.assume(_scenario.mintedCollateral >= _scenario.lockedCollateral);
    _scenario.generatedDebt = bound(
      _scenario.generatedDebt,
      (_scenario.lockedCollateral * (100)) / 10_000,
      (_scenario.lockedCollateral * (74 * 100)) / 10_000
    );
    _token.mint(alice, _scenario.mintedCollateral);

    _;
  }

  function _depositAndGen(Scenario memory _scenario) internal {
    vm.prank(alice);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, _scenario.generatedDebt, aliceProxy);
  }

  function test_ModifySafeCollateralization_LockCollateral(Scenario memory _scenario) public happyPath(_scenario) {
    vm.prank(alice);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, 0, aliceProxy);
    assertEq(safeEngine.safes(_cType(), aliceData.safeHandler).lockedCollateral, _scenario.lockedCollateral);
    assertEq(safeEngine.safes(_cType(), aliceData.safeHandler).generatedDebt, 0);
  }

  function test_ModifySafeCollateralization_LockCollateral_GenDebt(Scenario memory _scenario)
    public
    happyPath(_scenario)
  {
    if (_scenario.generatedDebt > 0) {
      vm.expectEmit(address(vault721));
      emit NFVStateUpdated(aliceSafeId);
    }
    _depositAndGen(_scenario);
    assertEq(safeEngine.safes(_cType(), aliceData.safeHandler).lockedCollateral, _scenario.lockedCollateral);
    assertEq(safeEngine.safes(_cType(), aliceData.safeHandler).generatedDebt, _scenario.generatedDebt);
  }

  function test_ModifySafeCollateralization_RepaySomeDebt(Scenario memory _scenario) public happyPath(_scenario) {
    _depositAndGen(_scenario);
    uint256 startingDebt = safeEngine.safes(_cType(), aliceData.safeHandler).generatedDebt;
    uint256 debtToRepay = startingDebt * 7500 / 1e4;
    vm.startPrank(alice);
    systemCoin.approve(aliceProxy, type(uint256).max);
    repayDebt(aliceSafeId, debtToRepay, aliceProxy);
    assertEq(safeEngine.safes(_cType(), aliceData.safeHandler).generatedDebt, startingDebt - debtToRepay);
  }

  function test_ModifySafeCollateralization_RepayAllDebt(Scenario memory _scenario) public happyPath(_scenario) {
    _depositAndGen(_scenario);
    // give alice some more system coin to pay off her debt
    uint256 totalDebt = safeEngine.safes(_cType(), aliceData.safeHandler).generatedDebt;
    uint256 debtToMint = totalDebt - systemCoin.balanceOf(alice);
    vm.prank(deployer);
    systemCoin.mint(alice, debtToMint);
    vm.startPrank(alice);
    systemCoin.approve(aliceProxy, type(uint256).max);
    repayAllDebt(aliceSafeId, aliceProxy);
    assertEq(safeEngine.safes(_cType(), aliceData.safeHandler).generatedDebt, 0);
  }

  function test_ModifySafeCollateralization_Revert_SafeNotAllowed() public {
    bobProxy = deployOrFind(bob);
    _token.mint(bob, 100 ether);
    vm.startPrank(bob);
    _token.approve(bobProxy, type(uint256).max);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    depositCollatAndGenDebt(_cType(), aliceSafeId, 100 ether, 0, bobProxy);
  }

  function test_ModifySafeCollateralization_NonSafeHandler() public {}
}

contract E2ESafeManagerTest_TransferCollateral is E2ESafeManagerSetUp {
  event TransferCollateral(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _wad);
  event TransferCollateral(address indexed _sender, bytes32 _cType, uint256 indexed _safe, address _dst, uint256 _wad);

  struct Scenario {
    uint256 mintedCollateral;
    uint256 lockedCollateral;
  }

  function setUp() public override {
    super.setUp();

    bobProxy = deployOrFind(bob);
    bobSafeId = safeManager.openSAFE(_cType(), bobProxy);
    bobData = safeManager.safeData(bobSafeId);
  }

  modifier happyPath(Scenario memory _scenario) {
    ISAFEEngine.SAFEEngineCollateralParams memory safeEngineParams = safeEngine.cParams(_cType());
    ISAFEEngine.SAFEEngineCollateralData memory cData = safeEngine.cData(_cType());
    vm.assume(notOverflowMul(_scenario.mintedCollateral, cData.accumulatedRate));
    vm.assume(
      _scenario.mintedCollateral > 10_000
        && _scenario.mintedCollateral * cData.accumulatedRate < safeEngineParams.debtCeiling
    );
    vm.assume(_scenario.mintedCollateral >= _scenario.lockedCollateral);
    _token.mint(alice, _scenario.mintedCollateral);

    _;
  }

  function _depositCollateral(Scenario memory _scenario) internal {
    vm.prank(alice);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, 0, aliceProxy);
  }

  function test_TransferCollateral(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(alice);
    _token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, 0, aliceProxy);
    assertEq(safeEngine.tokenCollateral(_cType(), bob), 0, 'unequal collateral');
    modifySAFECollateralization(aliceProxy, aliceSafeId, -int256(_scenario.lockedCollateral), 0);
    vm.stopPrank();
    vm.prank(alice);
    transferCollateral(aliceProxy, aliceSafeId, bob, _scenario.lockedCollateral);
    assertEq(safeEngine.tokenCollateral(_cType(), bob), _scenario.lockedCollateral, 'unequal collateral');
  }

  function test_TransferCollateral_Revert_SafeNotAllowed() public {
    vm.prank(alice);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    transferCollateral(aliceProxy, bobSafeId, bob, 1 ether);
  }

  function test_TransferCollateral_CType(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(alice);
    _token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, 0, aliceProxy);
    modifySAFECollateralization(aliceProxy, aliceSafeId, -int256(_scenario.lockedCollateral), 0);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.transferCollateralWithCType.selector,
      address(safeManager),
      _cType(),
      aliceSafeId,
      alice,
      _scenario.lockedCollateral
    );
    ODProxy(aliceProxy).execute(address(basicActions), payload);
    vm.stopPrank();
    assertEq(safeEngine.tokenCollateral(_cType(), alice), _scenario.lockedCollateral);
  }

  function test_TransferCollateral_CType_SafeNotAllowed(Scenario memory _scenario) public happyPath(_scenario) {
    vm.startPrank(alice);
    _token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, 0, aliceProxy);
    modifySAFECollateralization(aliceProxy, aliceSafeId, -int256(_scenario.lockedCollateral), 0);
    vm.stopPrank();
    bytes memory payload = abi.encodeWithSelector(
      basicActions.transferCollateralWithCType.selector,
      address(safeManager),
      _cType(),
      aliceSafeId,
      bob,
      _scenario.lockedCollateral
    );
    vm.prank(bob);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    safeManager.transferCollateral(_cType(), aliceSafeId, bob, _scenario.lockedCollateral);
  }
}

contract E2ESafeManagerTest_TransferInternalCoins is E2ESafeManagerSetUp {
  event TransferInternalCoins(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _rad);

  function setUp() public override {
    super.setUp();
    bobProxy = deployOrFind(bob);
    bobSafeId = safeManager.openSAFE(_cType(), bobProxy);
    bobData = safeManager.safeData(bobSafeId);
  }

  function test_TransferInternalCoins() public {
    vm.prank(address(timelockController));
    safeEngine.createUnbackedDebt(aliceData.safeHandler, aliceData.safeHandler, 1 ether * RAY);
    vm.prank(alice);
    vm.expectEmit();
    emit TransferInternalCoins(aliceProxy, aliceSafeId, bobData.safeHandler, 1 ether);
    transferInternalCoins(aliceProxy, aliceSafeId, bobData.safeHandler, 1 ether);
    assertEq(safeEngine.coinBalance(bobData.safeHandler), 1 ether);
  }

  function test_TransferInternalCoins_Revert_SafeNotAllowerd() public {
    vm.prank(address(timelockController));
    safeEngine.createUnbackedDebt(aliceData.safeHandler, aliceData.safeHandler, 1 ether * RAY);
    vm.prank(alice);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    transferInternalCoins(aliceProxy, bobSafeId, bobData.safeHandler, 1 ether);
  }
}

contract E2ESafeManagerTest_QuitSystem is E2ESafeManagerSetUp {
  event QuitSystem(address indexed _sender, uint256 indexed _safe, address _dst);

  function setUp() public override {
    super.setUp();
    bobProxy = deployOrFind(bob);
    bobSafeId = safeManager.openSAFE(_cType(), bobProxy);
    bobData = safeManager.safeData(bobSafeId);
  }

  struct Scenario {
    uint256 mintedCollateral;
    uint256 generatedDebt;
    uint256 lockedCollateral;
  }

  modifier happyPath(Scenario memory _scenario) {
    ISAFEEngine.SAFEEngineCollateralParams memory safeEngineParams = safeEngine.cParams(_cType());
    ISAFEEngine.SAFEEngineCollateralData memory cData = safeEngine.cData(_cType());
    vm.assume(notOverflowMul(_scenario.mintedCollateral, cData.accumulatedRate));
    vm.assume(
      _scenario.mintedCollateral > 10_000
        && _scenario.mintedCollateral * cData.accumulatedRate < safeEngineParams.debtCeiling
    );
    vm.assume(_scenario.mintedCollateral >= _scenario.lockedCollateral);
    _scenario.generatedDebt = bound(
      _scenario.generatedDebt,
      (_scenario.lockedCollateral * (100)) / 10_000,
      (_scenario.lockedCollateral * (74 * 100)) / 10_000
    );
    _token.mint(alice, _scenario.mintedCollateral);
    _;
  }

  function test_QuitSystem(Scenario memory _scenario) public happyPath(_scenario) {
    // alice's proxy has to approve the safeManager on the safe engine in order to transfer collateral.
    vm.prank(aliceProxy);
    safeEngine.approveSAFEModification(address(safeManager));
    vm.startPrank(alice);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, _scenario.generatedDebt, aliceProxy);

    vm.expectEmit(address(safeManager));
    emit QuitSystem(aliceProxy, aliceSafeId, aliceProxy);

    quitSystem(aliceProxy, aliceSafeId);
    assertEq(safeEngine.coinBalance(aliceProxy), 0);
    assertEq(safeEngine.safes(_cType(), aliceProxy).generatedDebt, _scenario.generatedDebt);
    assertEq(safeEngine.safes(_cType(), aliceProxy).lockedCollateral, _scenario.lockedCollateral);
  }

  function test_QuitSystem_Revert_SafeNotAllowed() public {
    vm.startPrank(alice);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    quitSystem(aliceProxy, bobSafeId);
  }
}

contract E2ESafeManagerTest_MoveSAFE is E2ESafeManagerSetUp {
  event QuitSystem(address indexed _sender, uint256 indexed _safe, address _dst);
  event MoveSAFE(address indexed _sender, uint256 indexed _safeSrc, uint256 indexed _safeDst);

  function setUp() public override {
    super.setUp();
    bobProxy = deployOrFind(bob);
    bobSafeId = safeManager.openSAFE(_cType(), bobProxy);
    bobData = safeManager.safeData(bobSafeId);
  }

  struct Scenario {
    uint256 mintedCollateral;
    uint256 generatedDebt;
    uint256 lockedCollateral;
  }

  modifier happyPath(Scenario memory _scenario) {
    ISAFEEngine.SAFEEngineCollateralParams memory safeEngineParams = safeEngine.cParams(_cType());
    ISAFEEngine.SAFEEngineCollateralData memory cData = safeEngine.cData(_cType());
    vm.assume(notOverflowMul(_scenario.mintedCollateral, cData.accumulatedRate));
    vm.assume(
      _scenario.mintedCollateral > 10_000
        && _scenario.mintedCollateral * cData.accumulatedRate < safeEngineParams.debtCeiling
    );
    vm.assume(_scenario.mintedCollateral >= _scenario.lockedCollateral);
    _scenario.generatedDebt = bound(
      _scenario.generatedDebt,
      (_scenario.lockedCollateral * (100)) / 10_000,
      (_scenario.lockedCollateral * (74 * 100)) / 10_000
    );
    _token.mint(alice, _scenario.mintedCollateral);
    _;
  }

  function test_MoveSafe(Scenario memory _scenario) public happyPath(_scenario) {
    // alice's proxy has to approve the safeManager on the safe engine in order to transfer collateral.
    vm.prank(aliceProxy);
    safeEngine.approveSAFEModification(address(safeManager));
    vm.startPrank(bobProxy);
    safeEngine.approveSAFEModification(address(safeManager));
    // bob must approve aliceProxy on the safeManager
    safeManager.allowSAFE(bobSafeId, aliceProxy, true);
    vm.stopPrank();
    vm.startPrank(alice);
    depositCollatAndGenDebt(_cType(), aliceSafeId, _scenario.lockedCollateral, _scenario.generatedDebt, aliceProxy);

    vm.expectEmit(address(safeManager));
    emit MoveSAFE(aliceProxy, aliceSafeId, bobSafeId);

    moveSAFE(aliceProxy, aliceSafeId, bobSafeId);

    assertEq(safeEngine.safes(_cType(), bobData.safeHandler).generatedDebt, _scenario.generatedDebt);
    assertEq(safeEngine.safes(_cType(), bobData.safeHandler).lockedCollateral, _scenario.lockedCollateral);
  }

  function test_MoveSafe_Revert_SafeNotAllowed() public {
    vm.startPrank(alice);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    moveSAFE(aliceProxy, bobSafeId, aliceSafeId);
  }
}

contract E2ESafeManagerTest_AddRemoveSafe is E2ESafeManagerSetUp {
  function test_AddSafe() public {
    uint256[] memory _safes = safeManager.getSafes(alice);
    assertEq(_safes.length, 0);

    vm.prank(alice);
    safeManager.addSAFE(aliceSafeId);

    _safes = safeManager.getSafes(alice);
    assertEq(_safes.length, 1);
    assertEq(_safes[0], aliceSafeId);
  }

  function test_RemoveSafe() public {
    uint256[] memory _safes = safeManager.getSafes(aliceProxy);
    assertEq(_safes.length, 1);
    vm.prank(aliceProxy);
    safeManager.removeSAFE(aliceSafeId);

    _safes = safeManager.getSafes(aliceProxy);
    assertEq(_safes.length, 0);
  }

  function test_RemoveSafe_RevertSafeNotAllowed() public {
    vm.startPrank(alice);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    safeManager.removeSAFE(aliceSafeId);
  }
}

contract E2ESafeManagerTest_ProtectSAFE is E2ESafeManagerSetUp {
  address testSaviour;

  function setUp() public override {
    super.setUp();
    testSaviour = address(new SafeSaviourForForTest());
    vm.prank(address(timelockController));
    liquidationEngine.connectSAFESaviour(testSaviour);
  }

  function test_ProtectSafe() public {
    vm.prank(aliceProxy);
    safeManager.protectSAFE(aliceSafeId, testSaviour);
    assertEq(liquidationEngine.chosenSAFESaviour(_cType(), aliceData.safeHandler), testSaviour);
  }

  function test_ProtectSafe_Revert_SafeNotAllowed() public {
    vm.prank(bobProxy);
    vm.expectRevert(IODSafeManager.SafeNotAllowed.selector);
    safeManager.protectSAFE(aliceSafeId, testSaviour);
  }
}

contract E2ESafeManagerTest_ModifyParameters is E2ESafeManagerSetUp {
  function test_ModifyParams_LiquidationEngine() public {
    vm.prank(address(deployer));
    safeManager.modifyParameters('liquidationEngine', abi.encode(address(1)));
    assertEq(safeManager.liquidationEngine(), address(1));
  }

  function test_ModifyParams_LiquidationEngine_RevertNullAddress() public {
    vm.prank(address(deployer));
    vm.expectRevert(Assertions.NullAddress.selector);
    safeManager.modifyParameters('liquidationEngine', abi.encode(address(0)));
  }

  function test_ModifyParams_TaxCollector() public {
    vm.prank(address(deployer));
    safeManager.modifyParameters('taxCollector', abi.encode(address(1)));
    assertEq(safeManager.taxCollector(), address(1));
  }

  function test_ModifyParams_TaxCollector_RevertNullAddress() public {
    vm.prank(address(deployer));
    vm.expectRevert(Assertions.NullAddress.selector);
    safeManager.modifyParameters('taxCollector', abi.encode(address(0)));
  }

  function test_ModifyParams_Vault721() public {
    vm.prank(address(deployer));
    safeManager.modifyParameters('vault721', abi.encode(address(1)));
    assertEq(address(safeManager.vault721()), address(1));
  }

  function test_ModifyParams_Vault721_RevertNullAddress() public {
    vm.prank(address(deployer));
    vm.expectRevert(Assertions.NullAddress.selector);
    safeManager.modifyParameters('vault721', abi.encode(address(0)));
  }

  function test_ModifyParams_SafeEngine() public {
    vm.prank(address(deployer));
    safeManager.modifyParameters('safeEngine', abi.encode(address(1)));
    assertEq(safeManager.safeEngine(), address(1));
  }

  function test_ModifyParams_SafeEngine_RevertNullAddress() public {
    vm.prank(address(deployer));
    vm.expectRevert(Assertions.NullAddress.selector);
    safeManager.modifyParameters('safeEngine', abi.encode(address(0)));
  }
}
