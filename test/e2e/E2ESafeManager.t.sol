// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, TKN, RAY, COLLAT, DEBT} from './Common.t.sol';
import {Base_CType} from '@test/scopes/Base_CType.t.sol';
import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {SafeSaviourForForTest} from '@test/mocks/SafeSaviourForTest.sol';

import {HOUR, YEAR} from '@libraries/Math.sol';

abstract contract E2ESafeMangerSetUp is Base_CType, Common {
  address aliceProxy;
  address bobProxy;

  address testSaviour;

  uint256 aliceSafeId;
  uint256 bobSafeId;

  IODSafeManager.SAFEData public aliceData;

  event TransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);

  function setUp() public override {
    super.setUp();
    super.setupEnvironment();
    aliceProxy = deployOrFind(alice);
    aliceSafeId = safeManager.openSAFE(_cType(), aliceProxy);
    aliceData = safeManager.safeData(aliceSafeId);
    testSaviour = address(new SafeSaviourForForTest());
    vm.prank(address(timelockController));
    liquidationEngine.connectSAFESaviour(testSaviour);
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
    return bytes32(abi.encodePacked('CTYPE1'));
  }

  function _removeDelays() internal {
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters('timeDelay', abi.encode(0 days));
    vault721.modifyParameters('blockDelay', abi.encode(0));
    vm.stopPrank();
  }
}

contract E2ESafeManagerTest is E2ESafeMangerSetUp {
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
