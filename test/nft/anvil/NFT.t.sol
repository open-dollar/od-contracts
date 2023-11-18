// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AnvilFork} from '@test/nft/anvil/AnvilFork.t.sol';
import {WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/GoerliParams.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

// forge t --fork-url $URL --match-contract NFTAnvil -vvvvv

contract NFTAnvil is AnvilFork {
  using SafeERC20 for IERC20;

  /**
   * @dev enfore correct setup
   */
  function test_setup() public {
    assertEq(totalVaults, vault721.totalSupply());
    checkProxyAddress();
    checkVaultIds();
  }

  /**
   * @dev modifiers to enforce value range
   */
  modifier maxLock(uint256 collateral) {
    vm.assume(collateral <= MINT_AMOUNT);
    _;
  }

  modifier debtRange(uint256 debt) {
    vm.assume(debt > 1 ether);
    vm.assume(debt < debtCeiling);
    _;
  }

  /**
   * @dev fuzz tests set to 256 runs each
   * test locking collateral
   */
  function test_depositCollateral(uint256 collateral, uint256 cTypeIndex) public maxLock(collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    for (uint256 i = 0; i < proxies.length; i++) {
      address proxy = proxies[i];
      bytes32 cType = cTypes[cTypeIndex];
      uint256 vaultId = vaultIds[proxy][cType];
      vm.startPrank(users[i]);
      depositCollatAndGenDebt(cType, vaultId, collateral, 0, proxy);
      vm.stopPrank();

      IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
      address safeHandler = sData.safeHandler;
      ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
      assertEq(collateral, SafeEngineData.lockedCollateral);
      assertEq(0, SafeEngineData.generatedDebt);
    }
  }

  /**
   * @dev test generating debt after locking collateral
   */
  function test_generateDebt(uint256 debt, uint256 collateral, uint256 cTypeIndex) public debtRange(debt) {
    collateral = bound(collateral, debt / 975, MINT_AMOUNT); // ETH price ~ 1500 (debt / 975 > 150% collateralization)
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 2); // range: WSTETH, CBETH, RETH

    for (uint256 i = 0; i < proxies.length; i++) {
      address proxy = proxies[i];
      bytes32 cType = cTypes[cTypeIndex];
      uint256 vaultId = vaultIds[proxy][cType];
      vm.startPrank(users[i]);
      depositCollatAndGenDebt(cType, vaultId, collateral, 0, proxy);
      genDebt(vaultId, debt, proxy);
      vm.stopPrank();

      IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
      address safeHandler = sData.safeHandler;
      ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
      assertEq(collateral, SafeEngineData.lockedCollateral);
      assertEq(debt, SafeEngineData.generatedDebt);
    }
  }

  /**
   * @dev test generating debt and locking collateral in single tx
   */
  function test_depositCollateral_generateDebt(
    uint256 debt,
    uint256 collateral,
    uint256 cTypeIndex
  ) public debtRange(debt) {
    collateral = bound(collateral, debt / 975, MINT_AMOUNT);
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 2);

    for (uint256 i = 0; i < proxies.length; i++) {
      address proxy = proxies[i];
      bytes32 cType = cTypes[cTypeIndex];
      uint256 vaultId = vaultIds[proxy][cType];
      vm.startPrank(users[i]);
      depositCollatAndGenDebt(cType, vaultId, collateral, debt, proxy);
      vm.stopPrank();

      IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
      address safeHandler = sData.safeHandler;
      ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
      assertEq(collateral, SafeEngineData.lockedCollateral);
      assertEq(debt, SafeEngineData.generatedDebt);
    }
  }

  /**
   * @dev test transfering vault to outside user
   */
  function test_transferVault(uint256 vaultId) public {
    vaultId = bound(vaultId, 1, totalVaults - 1);
    address owner = vault721.ownerOf(vaultId);
    uint256 initBal = vault721.balanceOf(owner);

    address receiver = newUsers[0];

    vm.startPrank(owner);
    vault721.transferFrom(owner, receiver, vaultId);
    vm.stopPrank();

    assertEq(receiver, vault721.ownerOf(vaultId));
    assertEq(initBal - 1, vault721.balanceOf(owner));
    assertEq(1, vault721.balanceOf(receiver));
  }

  /**
   * @dev verify no burn
   */
  function test_transferVault_toZero_Fail(uint256 vaultId) public {
    vaultId = bound(vaultId, 1, totalVaults - 1);
    address owner = vault721.ownerOf(vaultId);
    uint256 initBal = vault721.balanceOf(owner);

    address receiver = address(0);

    vm.startPrank(owner);
    vm.expectRevert('ERC721: transfer to the zero address');
    vault721.transferFrom(owner, receiver, vaultId);
    vm.stopPrank();

    assertEq(initBal, vault721.balanceOf(owner));
  }

  /**
   * @dev Test transfering collateral to an address
   * that isn't a safeHandler reverts.
   */
  function test_transferCollateral_Fail(uint256 cTypeIndex) public {
    address owner = users[0];
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 2);
    // @note TODO I believe this is a naive way of opening a safe
    // and transferring collateral, but is still tests the new code
    vm.startPrank(owner);
    uint256 id = safeManager.openSAFE(cTypes[cTypeIndex], owner);
    vm.expectRevert(IODSafeManager.HandlerDoesNotExist.selector);
    safeManager.transferCollateral(id, owner, 1 ether);
    vm.stopPrank();
  }

  /**
   * @dev Test transfering collateral to an address that is a safeHandler
   * succeeds
   */
  function test_transferCollateralToSafeHandler(uint256 cTypeIndex) public {
    address alice = users[0];
    address bob = users[1];
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 2);
    vm.startPrank(alice);
    uint256 aliceSafeId = safeManager.openSAFE(cTypes[cTypeIndex], alice);
    // TODO I need to figure out how to deposit collateral otherwise
    // the transfer collateral below fails
    vm.stopPrank();

    vm.startPrank(bob);
    uint256 bobSafeId = safeManager.openSAFE(cTypes[cTypeIndex], alice);
    vm.stopPrank();

    IODSafeManager.SAFEData memory bobSafeData = safeManager.safeData(bobSafeId);

    vm.startPrank(alice);
    safeManager.transferCollateral(aliceSafeId, bobSafeData.safeHandler, 0);
    // TODO I need to figure out a different way of calling 
    // transferCollateral, as the isSAFEAllowed modifier will fail in SAFEEngine.sol
    vm.stopPrank();
  }
}
