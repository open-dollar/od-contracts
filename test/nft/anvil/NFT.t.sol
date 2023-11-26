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

    address reciever = newUsers[0];

    vm.startPrank(owner);
    vault721.transferFrom(owner, reciever, vaultId);
    vm.stopPrank();

    assertEq(reciever, vault721.ownerOf(vaultId));
    assertEq(initBal - 1, vault721.balanceOf(owner));
    assertEq(1, vault721.balanceOf(reciever));
  }

  /**
   * @dev verify no burn
   */
  function test_transferVault_toZero_Fail(uint256 vaultId) public {
    vaultId = bound(vaultId, 1, totalVaults - 1);
    address owner = vault721.ownerOf(vaultId);
    uint256 initBal = vault721.balanceOf(owner);

    address reciever = address(0);

    vm.startPrank(owner);
    vm.expectRevert('ERC721: transfer to the zero address');
    vault721.transferFrom(owner, reciever, vaultId);
    vm.stopPrank();

    assertEq(initBal, vault721.balanceOf(owner));
  }

  /**
   * @dev fuzz tests set to 256 runs each
   * test locking collateral
   */
  function test_allowSAFE(uint256 cTypeIndex, uint8 ok) public {
    vm.assume(ok < 2);
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
    uint256 i = 0;
    address proxy = proxies[i];
    bytes32 cType = cTypes[cTypeIndex];
    uint256 vaultId = vaultIds[proxy][cType];
    vm.startPrank(users[i]);
    allowSafe(proxy, vaultId, users[i], ok);
    vm.stopPrank();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);

    assertEq(safeManager.safeCan(sData.owner, vaultId, users[i]), ok, 'test_allowSAFE: safeCan not set correctly');
  }

  function test_allowHandler(uint256 cTypeIndex, uint8 ok) public {
    vm.assume(ok < 2);
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
    uint256 i = 0;
    address proxy = proxies[i];
    bytes32 cType = cTypes[cTypeIndex];
    uint256 vaultId = vaultIds[proxy][cType];
    vm.startPrank(users[i]);
    allowHandler(proxy, users[i], ok);
    vm.stopPrank();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);

    assertEq(safeManager.handlerCan(proxy, users[i]), ok, 'test_allowHandler: handlerCan not set correctly');
  }

  // function test_modifySAFECollateralization(
  //   uint256 cTypeIndex,
  //   uint256 collateral,
  //   int256 deltaDebt
  // ) public maxLock(collateral) {
  //   cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
  //   uint256 i = 0;
  //   address proxy = proxies[i];
  //   bytes32 cType = cTypes[cTypeIndex];
  //   uint256 vaultId = vaultIds[proxy][cType];
  //   vm.startPrank(users[i]);
  //   modifySAFECollateralization(proxy, vaultId, int256(collateral), deltaDebt);
  //   vm.stopPrank();
  // }

  // function test_transferCollateral(uint256 cTypeIndex, uint256 collateral) public maxLock(collateral) {
  //   cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
  //   uint256 i = 0;
  //   address proxy = proxies[i];
  //   bytes32 cType = cTypes[cTypeIndex];
  //   uint256 vaultId = vaultIds[proxy][cType];
  //   uint256 destId = vaultIds[proxies[1]][cType];
  //   IODSafeManager.SAFEData memory sData = safeManager.safeData(destId);
  //   vm.startPrank(users[i]);
  //   transferCollateral(proxy, vaultId, sData.safeHandler, collateral);
  //   vm.stopPrank();
  // }

  // function test_transferInternalCoins(uint256 cTypeIndex, address _dst, uint256 _rad) public {
  //   cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
  //   uint256 i = 0;
  //   address proxy = proxies[i];
  //   bytes32 cType = cTypes[cTypeIndex];
  //   uint256 vaultId = vaultIds[proxy][cType];
  //   vm.startPrank(users[i]);
  //   transferInternalCoins(proxy, vaultId, _dst, _rad);
  //   vm.stopPrank();
  // }

  // function test_quitSystem(uint256 cTypeIndex, address _dst) public {
  //   cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
  //   uint256 i = 0;
  //   address proxy = proxies[i];
  //   bytes32 cType = cTypes[cTypeIndex];
  //   uint256 vaultId = vaultIds[proxy][cType];
  //   vm.startPrank(users[i]);
  //   quitSystem(proxy, vaultId, _dst);
  //   vm.stopPrank();
  // }

  // function test_enterSystem(uint256 cTypeIndex, address _src) public {
  //   cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
  //   uint256 i = 0;
  //   address proxy = proxies[i];
  //   bytes32 cType = cTypes[cTypeIndex];
  //   uint256 vaultId = vaultIds[proxies[1]][cType];
  //   vm.startPrank(users[i]);
  //   enterSystem(proxy, _src, vaultId);
  //   vm.stopPrank();
  // }

  // function test_moveSAFE(uint256 cTypeIndex) public {
  //   cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
  //   uint256 i = 0;
  //   address proxy = proxies[i];
  //   bytes32 cType = cTypes[cTypeIndex];
  //   uint256 vaultId = vaultIds[proxy][cType];
  //   uint256 anotherVaultId = vaultIds[proxies[1]][cType];
  //   vm.startPrank(users[i]);
  //   moveSAFE(proxy, vaultId, anotherVaultId);
  //   vm.stopPrank();
  // }

  function test_addSAFE(uint256 cTypeIndex) public {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
    uint256 i = 0;
    address proxy = proxies[i];
    bytes32 cType = cTypes[cTypeIndex];
    uint256 vaultId = vaultIds[proxy][cType];
    uint256 anotherVaultId = vaultIds[proxies[1]][cType];
    vm.startPrank(users[i]);
    addSAFE(proxy, anotherVaultId);
    vm.stopPrank();
  }

  function test_removeSAFE(uint256 cTypeIndex) public {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
    uint256 i = 0;
    address proxy = proxies[i];
    bytes32 cType = cTypes[cTypeIndex];
    uint256 vaultId = vaultIds[proxy][cType];
    vm.startPrank(users[i]);
    removeSAFE(proxy, vaultId);
    vm.stopPrank();
  }

  // function test_protectSAFE(uint256 cTypeIndex) public {
  //   cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
  //   uint256 i = 0;
  //   address saviour = address(0x420);
  //   address proxy = proxies[i];
  //   bytes32 cType = cTypes[cTypeIndex];
  //   uint256 vaultId = vaultIds[proxy][cType];
  //   vm.startPrank(users[i]);
  //   protectSAFE(proxy, vaultId, address(liquidationEngine), saviour);
  //   vm.stopPrank();
  // }
}
