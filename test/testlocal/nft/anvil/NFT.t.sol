// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AnvilFork} from '@testlocal/nft/anvil/AnvilFork.t.sol';
import {WSTETH, ARB, CBETH, RETH} from '@script/SepoliaParams.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {HashState, Vault721} from '@contracts/proxies/Vault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {FakeBasicActions} from '@testlocal/nft/anvil/FakeBasicActions.sol';

// forge t --fork-url http://127.0.0.1:8545 --match-contract NFTAnvil -vvvvv

contract NFTAnvil is AnvilFork {
  using SafeERC20 for IERC20;

  function setUp() public override {
    super.setUp();
    vm.startPrank(vault721.timelockController());
    vault721.updateTimeDelay(5 days);
    vault721.updateBlockDelay(3);
    vm.stopPrank();
  }
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
  modifier maxLock(uint256 _collateral) {
    vm.assume(_collateral <= MINT_AMOUNT);
    _;
  }

  function _helperDepositCollateralAndGenerateDebt(
    address owner,
    address proxy,
    bytes32 cType,
    uint256 _collateral,
    uint256 debt
  ) internal returns (uint256 vaultId) {
    vaultId = vaultIds[proxy][cType];
    vm.startPrank(owner);
    depositCollatAndGenDebt(cType, vaultId, _collateral, debt, proxy);
    vm.stopPrank();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
    address safeHandler = sData.safeHandler;
    ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
    assertEq(
      _collateral, SafeEngineData.lockedCollateral, '_helperDepositCollateralAndGenerateDebt: collateral not equal'
    );
    assertEq(debt, SafeEngineData.generatedDebt, '_helperDepositCollateralAndGenerateDebt: debt not equal');
  }

  /**
   * @dev fuzz tests set to 256 runs each
   * test locking collateral
   */
  function test_depositCollateral(uint256 _collateral, uint256 cTypeIndex) public maxLock(_collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    for (uint256 i = 0; i < proxies.length; i++) {
      _helperDepositCollateralAndGenerateDebt(users[i], proxies[i], cTypes[cTypeIndex], _collateral, 0);
    }
  }

  /**
   * @dev test generating debt after locking collateral
   */
  function test_generateDebt(uint256 debt, uint256 _collateral, uint256 cTypeIndex) public {
    debt = bound(debt, 1 ether, debtCeiling);
    _collateral = bound(_collateral, debt / 975, MINT_AMOUNT); // ETH price ~ 1500 (debt / 975 > 150% collateralization)
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 2); // range: WSTETH, CBETH, RETH

    for (uint256 i = 0; i < proxies.length; i++) {
      address proxy = proxies[i];
      bytes32 cType = cTypes[cTypeIndex];
      uint256 vaultId = vaultIds[proxy][cType];
      vm.startPrank(users[i]);
      depositCollatAndGenDebt(cType, vaultId, _collateral, 0, proxy);
      genDebt(vaultId, debt, proxy);
      vm.stopPrank();

      IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
      address safeHandler = sData.safeHandler;
      ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
      assertEq(_collateral, SafeEngineData.lockedCollateral);
      assertEq(debt, SafeEngineData.generatedDebt);
    }
  }

  /**
   * @dev test generating debt and locking collateral in single tx
   */
  function test_depositCollateral_generateDebt(uint256 debt, uint256 _collateral, uint256 cTypeIndex) public {
    debt = bound(debt, 1 ether, debtCeiling);
    _collateral = bound(_collateral, debt / 975, MINT_AMOUNT);
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 2);

    for (uint256 i = 0; i < proxies.length; i++) {
      _helperDepositCollateralAndGenerateDebt(users[i], proxies[i], cTypes[cTypeIndex], _collateral, debt);
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
  function test_revert_If_TransferCollateral_To_NonSafeHandler(
    uint256 _collateral,
    uint256 cTypeIndex
  ) public maxLock(_collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
    address alice = users[0];
    address proxy = proxies[0]; // alice's proxy
    bytes32 cType = cTypes[cTypeIndex];
    uint256 vaultId = _helperDepositCollateralAndGenerateDebt(alice, proxy, cType, _collateral, 0);

    vm.startPrank(proxy);
    vm.expectRevert(IODSafeManager.HandlerDoesNotExist.selector);
    safeManager.transferCollateral(vaultId, alice, _collateral);
    vm.stopPrank();
  }

  /**
   * @dev Test transfering collateral to an address that is a safeHandler
   * succeeds
   */
  function test_transferCollateral_To_SafeHandler(uint256 _collateral, uint256 cTypeIndex) public maxLock(_collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC
    address alice = users[0];
    address aliceProxy = proxies[0]; // alice's proxy
    bytes32 cType = cTypes[cTypeIndex];
    uint256 aliceVaultId = _helperDepositCollateralAndGenerateDebt(alice, aliceProxy, cType, _collateral, 0);

    address bob = users[1];
    address bobProxy = proxies[1]; // bob's proxy
    uint256 bobVaultId = vaultIds[bobProxy][cType];

    IODSafeManager.SAFEData memory bobSafeData = safeManager.safeData(bobVaultId);
    address bobSafeHandler = bobSafeData.safeHandler;
    assertEq(
      safeEngine.safes(cType, bobSafeHandler).lockedCollateral,
      0,
      'test_transferCollateralToSafeHandler: collateral is empty'
    );

    vm.startPrank(aliceProxy);
    // @note TODO when we deposit collateral, it is locked, how do we move it from locked to tokenCollateral so
    // we can transfer it? this will fail if we try to transfer non-zero value
    safeManager.transferCollateral(aliceVaultId, bobSafeHandler, 0);
    vm.stopPrank();
    assertEq(
      safeEngine.tokenCollateral(cType, bobSafeHandler),
      0,
      'test_transferCollateralToSafeHandler: collateral is not equal'
    );
  }

  /**
   * @dev Test generating debt and repaying it
   */
  function test_generateDebtAndRepay(uint256 debt, uint256 _collateral, uint256 cTypeIndex) public {
    debt = bound(debt, 1 ether, debtCeiling);
    _collateral = bound(_collateral, debt / 975, MINT_AMOUNT); // ETH price ~ 1500 (debt / 975 > 150% collateralization)
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 2); // range: WSTETH, CBETH, RETH

    for (uint256 i = 0; i < proxies.length; i++) {
      address proxy = proxies[i];
      bytes32 cType = cTypes[cTypeIndex];
      uint256 vaultId = vaultIds[proxy][cType];
      vm.startPrank(users[i]);
      depositCollatAndGenDebt(cType, vaultId, _collateral, 0, proxy);
      genDebt(vaultId, debt, proxy);
      vm.stopPrank();

      IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
      address safeHandler = sData.safeHandler;
      ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
      assertEq(_collateral, SafeEngineData.lockedCollateral);
      assertEq(debt, SafeEngineData.generatedDebt);

      vm.startPrank(users[i]);
      systemCoin.approve(address(proxy), debt);
      repayDebt(vaultId, debt, proxy);
      vm.stopPrank();

      // debt should be paid off and no longer exist
      SafeEngineData = safeEngine.safes(cType, safeHandler);
      assertEq(SafeEngineData.generatedDebt, 0);
    }
  }

  function test_GenerateDebtWithoutTax(uint256 debt, uint256 collateral) public {
    debt = bound(debt, 1 ether, debtCeiling);
    collateral = bound(collateral, debt / 975, MINT_AMOUNT); // ETH price ~ 1500 (debt / 975 > 150% collateralization)
    FakeBasicActions fakeBasicActions = new FakeBasicActions();
    address proxy = proxies[1];
    bytes32 cType = cTypes[1];
    uint256 vaultId = vaultIds[proxy][cType];

    bytes memory payload = abi.encodeWithSelector(
      fakeBasicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[cType]),
      address(coinJoin),
      vaultId,
      collateral,
      0
    );
    vm.startPrank(users[1]);

    // Proxy makes a delegatecall to Malicious BasicAction contract and bypasses the TAX payment
    ODProxy(proxy).execute(address(fakeBasicActions), payload);
    genDebt(vaultId, debt, proxy);

    vm.stopPrank();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
    address safeHandler = sData.safeHandler;
    ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
    assertEq(collateral, SafeEngineData.lockedCollateral);
    assertEq(debt, SafeEngineData.generatedDebt);
  }

  // Access Control Tests
  function test_revert_If_UpdateVaultHashStateWhenNotSafeManager() public {
    vm.startPrank(users[0]);
    vm.expectRevert(Vault721.NotSafeManager.selector);
    vault721.updateVaultHashState(1);
    vm.stopPrank();
  }

  function test_revert_If_UpdateAllowlistWhenNotGovernance() public {
    vm.startPrank(users[0]);
    vm.expectRevert(Vault721.NotGovernor.selector);
    vault721.updateAllowlist(users[0], true);
    vm.stopPrank();
  }

  function test_revert_If_UpdateAllowlistForZeroAddress() public {
    vm.startPrank(vault721.timelockController());
    vm.expectRevert(Vault721.ZeroAddress.selector);
    vault721.updateAllowlist(address(0), true);
    vm.stopPrank();
  }

  function test_revert_If_UpdateTimeDelayWhenNotGovernance() public {
    vm.startPrank(users[0]);
    vm.expectRevert(Vault721.NotGovernor.selector);
    vault721.updateTimeDelay(3 days);
    vm.stopPrank();
  }

  function test_revert_If_UpdateBlockDelayWhenNotGovernance() public {
    vm.startPrank(users[0]);
    vm.expectRevert(Vault721.NotGovernor.selector);
    vault721.updateBlockDelay(3);
    vm.stopPrank();
  }

  function test_UpdateVaultHashState() public {
    vm.warp(420);
    vm.roll(69);
    vm.startPrank(address(safeManager));
    vault721.updateVaultHashState(1);
    vm.stopPrank();

    HashState memory hashState = vault721.getHashState(1);

    assertEq(hashState.lastBlockNumber, 69, 'test_UpdateVaultHashState: lastBlockNumber not set correctly');
    assertEq(hashState.lastBlockTimestamp, 420, 'test_UpdateVaultHashState: lastBlockTimestamp not set correctly');
  }

  function test_UpdateAllowlist() public {
    address allowedAddress = address(0x420);
    vm.startPrank(vault721.timelockController());
    vault721.updateAllowlist(allowedAddress, true);
    vm.stopPrank();

    assertEq(vault721.getIsAllowlisted(allowedAddress), true, 'test_UpdateAllowlist: allowlist not set correctly');
  }

  function test_UpdateTimeDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.updateTimeDelay(5 days);
    vm.stopPrank();

    assertEq(vault721.timeDelay(), 5 days, 'test_UpdateTimeDelay: timeDelay not set correctly');
  }

  function test_UpdateBlockDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.updateBlockDelay(3);
    vm.stopPrank();

    assertEq(vault721.blockDelay(), 3, 'test_UpdateBlockDelay: blockDelay not set correctly');
  }

  // NFV Frontrunning-specific Tests

  function test_revert_If_TransferFrom_When_TimeDelayNotReached(
    uint256 _collateral,
    uint256 cTypeIndex
  ) public maxLock(_collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    _helperDepositCollateralAndGenerateDebt(users[0], proxies[0], cTypes[cTypeIndex], _collateral, 0);
    vm.startPrank(users[0]);
    vm.expectRevert(Vault721.TimeDelayNotOver.selector);
    vault721.transferFrom(users[0], users[1], vaultIds[proxies[0]][cTypes[cTypeIndex]]);
    vm.stopPrank();
  }

  function test_revert_If_TransferFrom_When_BlockDelayNotReached(
    uint256 _collateral,
    uint256 cTypeIndex
  ) public maxLock(_collateral) {
    address allowedAddress = users[0];
    vm.startPrank(vault721.timelockController());
    vault721.updateAllowlist(allowedAddress, true);
    vm.stopPrank();

    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    _helperDepositCollateralAndGenerateDebt(users[0], proxies[0], cTypes[cTypeIndex], _collateral, 0);
    vm.startPrank(users[0]);
    vm.expectRevert(Vault721.BlockDelayNotOver.selector);
    vault721.transferFrom(users[0], users[1], vaultIds[proxies[0]][cTypes[cTypeIndex]]);
    vm.stopPrank();
  }

  function test_transerFromWithoutAnyDelays(uint256 cTypeIndex) public {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    vm.startPrank(users[0]);
    vault721.transferFrom(users[0], users[1], vaultIds[proxies[0]][cTypes[cTypeIndex]]);
    vm.stopPrank();
  }

  function test_transferFromAfterTimeDelayPassed(uint256 _collateral, uint256 cTypeIndex) public maxLock(_collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    _helperDepositCollateralAndGenerateDebt(users[0], proxies[0], cTypes[cTypeIndex], _collateral, 0);

    vm.warp(block.timestamp + vault721.timeDelay());

    vm.startPrank(users[0]);
    vault721.transferFrom(users[0], users[1], vaultIds[proxies[0]][cTypes[cTypeIndex]]);
    vm.stopPrank();
  }

  function test_transferFromAfterBlockDelayPassed(uint256 _collateral, uint256 cTypeIndex) public maxLock(_collateral) {
    address allowedAddress = users[0];
    vm.startPrank(vault721.timelockController());
    vault721.updateAllowlist(allowedAddress, true);
    vm.stopPrank();

    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    _helperDepositCollateralAndGenerateDebt(users[0], proxies[0], cTypes[cTypeIndex], _collateral, 0);

    vm.roll(block.number + vault721.blockDelay());

    vm.startPrank(users[0]);
    vault721.transferFrom(users[0], users[1], vaultIds[proxies[0]][cTypes[cTypeIndex]]);
    vm.stopPrank();
  }

  function test_modifySAFECollateralizationUpdatesVaultHashState(
    uint256 _collateral,
    uint256 cTypeIndex
  ) public maxLock(_collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    vm.roll(69);
    vm.warp(420);
    // this calls depositCollatAndGenDebt which calls BasicActions.lockTokenCollateralAndGenerateDebt
    // which does _modifySAFECollateralization
    _helperDepositCollateralAndGenerateDebt(users[0], proxies[0], cTypes[cTypeIndex], _collateral, 0);

    HashState memory hashState = vault721.getHashState(vaultIds[proxies[0]][cTypes[cTypeIndex]]);

    assertEq(
      hashState.lastBlockNumber,
      69,
      'test_modifySAFECollateralizationUpdatesVaultHashState: lastBlockNumber not set correctly'
    );
    assertEq(
      hashState.lastBlockTimestamp,
      420,
      'test_modifySAFECollateralizationUpdatesVaultHashState: lastBlockTimestamp not set correctly'
    );
  }

  function test_transferCollateralUpdatesVaultHashState(
    uint256 _collateral,
    uint256 cTypeIndex
  ) public maxLock(_collateral) {
    cTypeIndex = bound(cTypeIndex, 1, cTypes.length - 1); // range: WSTETH, CBETH, RETH, MAGIC

    vm.roll(69);
    vm.warp(420);

    address alice = users[0];
    address aliceProxy = proxies[0]; // alice's proxy
    bytes32 cType = cTypes[cTypeIndex];
    uint256 aliceVaultId = _helperDepositCollateralAndGenerateDebt(alice, aliceProxy, cType, _collateral, 0);

    address bob = users[1];
    address bobProxy = proxies[1]; // bob's proxy
    uint256 bobVaultId = vaultIds[bobProxy][cType];

    IODSafeManager.SAFEData memory bobSafeData = safeManager.safeData(bobVaultId);
    address bobSafeHandler = bobSafeData.safeHandler;

    vm.startPrank(aliceProxy);
    safeManager.transferCollateral(aliceVaultId, bobSafeHandler, 0);
    vm.stopPrank();

    HashState memory hashState = vault721.getHashState(aliceVaultId);

    assertEq(
      hashState.lastBlockNumber,
      69,
      'test_modifySAFECollateralizationUpdatesVaultHashState: lastBlockNumber not set correctly'
    );
    assertEq(
      hashState.lastBlockTimestamp,
      420,
      'test_modifySAFECollateralizationUpdatesVaultHashState: lastBlockTimestamp not set correctly'
    );
  }

  // BasicActions Call Tests
  function test_allowSAFE(uint256 cTypeIndex, bool ok) public {
    vm.assume(ok == true);
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

  function test_allowHandler(uint256 cTypeIndex, bool ok) public {
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
