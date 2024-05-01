// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, TKN, RAY, COLLAT, DEBT} from './Common.t.sol';
import {Base_CType} from '@test/scopes/Base_CType.t.sol';
import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';

import {HOUR, YEAR} from '@libraries/Math.sol';

abstract contract E2ESafeMangerSetUp is Base_CType, Common {
  address aliceProxy;
  address bobProxy;

  uint256 aliceSafeId;
  uint256 bobSafeId;

  function setUp() public override {
    super.setUp();
    super.setupEnvironment();
    aliceProxy = deployOrFind(alice);
    aliceSafeId = safeManager.openSAFE(_cType(), aliceProxy);
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
    (, address[] memory safeHandlers,) = safeManager.getSafesData(aliceProxy);
    IODSafeManager.SAFEData memory _data = safeManager.getSafeDataFromHandler(safeHandlers[0]);

    assertEq(_data.nonce, 0);
    assertEq(_data.owner, aliceProxy);
    assertEq(_data.collateralType, _cType());
    assertEq(_data.safeHandler, safeHandlers[0]);
  }

  function test_SafeData() public view {
    IODSafeManager.SAFEData memory _data = safeManager.safeData(aliceSafeId);
    assertEq(_data.nonce, 0);
    assertEq(_data.owner, aliceProxy);
    assertEq(_data.collateralType, _cType());
  }

  function test_AllowSafe() public {}
}
