// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Common, COLLAT, DEBT, TKN} from '@test/e2e/Common.t.sol';
import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {RAY, WAD} from '@libraries/Math.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {FakeBasicActions} from '@contracts/for-test/FakeBasicActions.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract NFTSetup is Common {
  uint256 public constant MINT_AMOUNT = 1000 ether;
  uint256 public constant MULTIPLIER = 10; // for over collateralization
  uint256 public debtCeiling;

  address public aliceProxy;
  address public bobProxy;

  ERC20ForTest public token;

  function setUp() public override {
    super.setUp();
    aliceProxy = deployOrFind(alice);
    bobProxy = deployOrFind(bob);
    vm.label(aliceProxy, 'AliceProxy');
    vm.label(bobProxy, 'BobProxy');

    token = ERC20ForTest(address(collateral[TKN]));
    token.mint(alice, MINT_AMOUNT);

    ISAFEEngine.SAFEEngineParams memory params = safeEngine.params();
    debtCeiling = params.safeDebtCeiling;
  }

  function deployOrFind(address owner) public returns (address) {
    address proxy = vault721.getProxy(owner);
    if (proxy == address(0)) {
      return address(vault721.build(owner));
    } else {
      return proxy;
    }
  }

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

  function openSafe() public returns (uint256 safeId) {
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), TKN, aliceProxy);
    bytes memory safeData = ODProxy(aliceProxy).execute(address(basicActions), payload);
    safeId = abi.decode(safeData, (uint256));
  }
}

contract E2ENFTTest is NFTSetup {
  function test_openSafe() public {
    vm.startPrank(alice);
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), TKN, aliceProxy);
    bytes memory safeData = ODProxy(aliceProxy).execute(address(basicActions), payload);
    vm.stopPrank();

    uint256 safeId = abi.decode(safeData, (uint256));
    assertEq(safeId, vault721.totalSupply());

    address safeIdOwner = Vault721(vault721).ownerOf(safeId);
    assertEq(safeIdOwner, alice);
  }

  function test_transferSafe() public {
    vm.startPrank(alice);
    uint256 safeId = openSafe();

    Vault721(vault721).transferFrom(alice, bob, safeId);
    vm.stopPrank();
  }

  function test_transferSafeToProxyFail() public {
    vm.startPrank(alice);
    uint256 safeId = openSafe();

    vm.expectRevert(IVault721.NotWallet.selector);
    Vault721(vault721).transferFrom(alice, bobProxy, safeId);
    vm.stopPrank();
  }

  function test_transferSafeToZeroFail() public {
    vm.startPrank(alice);
    uint256 safeId = openSafe();

    vm.expectRevert(IVault721.NotWallet.selector);
    Vault721(vault721).transferFrom(alice, bobProxy, safeId);
    vm.stopPrank();
  }

  function test_lockCollateral() public {
    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, MINT_AMOUNT, 0, aliceProxy);
    vm.stopPrank();
  }

  function test_lockCollateral_generateDebt() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, MINT_AMOUNT, MINT_AMOUNT / MULTIPLIER, aliceProxy);
    vm.stopPrank();
  }

  function test_openSafe_lockCollateral_transfer() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, MINT_AMOUNT, 0, aliceProxy);

    uint256 nftBalAliceBefore = Vault721(vault721).balanceOf(alice);
    uint256 nftBalBobBefore = Vault721(vault721).balanceOf(bob);

    assertEq(nftBalAliceBefore, 1);
    assertEq(nftBalBobBefore, 0);

    Vault721(vault721).transferFrom(alice, bob, safeId);

    uint256 nftBalAliceAfter = Vault721(vault721).balanceOf(alice);
    uint256 nftBalBobAfter = Vault721(vault721).balanceOf(bob);

    assertEq(nftBalAliceAfter, 0);
    assertEq(nftBalBobAfter, 1);
    vm.stopPrank();

    uint256[] memory _safes = safeManager.getSafes(deployOrFind(bob));
    assertEq(_safes.length, 1);
    assertEq(_safes[0], vault721.totalSupply());
  }

  function test_transferCollateral() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, vault721.totalSupply(), MINT_AMOUNT, 0, aliceProxy);

    assertEq(safeEngine.tokenCollateral(TKN, bob), 0, 'unequal collateral');

    IERC20(address(systemCoin)).approve(aliceProxy, 10 ether);
    modifySAFECollateralization(aliceProxy, safeId, -10 ether, 10 ether);
    transferCollateral(aliceProxy, safeId, bob, 10 ether);
    vm.stopPrank();

    assertEq(safeEngine.tokenCollateral(TKN, bob), 10 ether, 'unequal collateral');
  }
}

contract E2ENFTTestFuzz is NFTSetup {
  function test_lockCollateral(uint256 _collateral) public {
    _collateral = bound(_collateral, 0, MINT_AMOUNT);

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, 0, aliceProxy);
    vm.stopPrank();
  }

  function test_lockCollateral_generateDebt(uint256 _debt) public {
    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, _debt, aliceProxy);
    vm.stopPrank();
  }

  function test_generateDebtAndRepay(uint256 _debt) public {
    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(safeId);
    address safeHandler = sData.safeHandler;
    ISAFEEngine.SAFE memory SafeEngineData1 = safeEngine.safes(TKN, safeHandler);

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, vault721.totalSupply(), _collateral, _debt, aliceProxy);

    ISAFEEngine.SAFE memory SafeEngineData2 = safeEngine.safes(TKN, safeHandler);
    assertEq(
      SafeEngineData2.lockedCollateral, SafeEngineData1.lockedCollateral + _collateral, 'collateral not transfered'
    );
    assertEq(SafeEngineData2.generatedDebt, SafeEngineData1.generatedDebt + _debt, 'debt not generated');

    systemCoin.approve(address(aliceProxy), _debt);
    repayDebt(safeId, _debt, aliceProxy);
    vm.stopPrank();

    // debt should be paid off and no longer exist
    ISAFEEngine.SAFE memory safeEngineData = safeEngine.safes(TKN, safeHandler);
    assertEq(safeEngineData.generatedDebt, SafeEngineData2.generatedDebt - _debt, 'debt not repaid');
  }

  function test_GenerateDebtWithoutTax(uint256 _debt) public {
    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);
    FakeBasicActions fakeBasicActions = new FakeBasicActions();

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(safeId);
    address safeHandler = sData.safeHandler;
    ISAFEEngine.SAFE memory safeEngineData1 = safeEngine.safes(TKN, safeHandler);

    bytes memory payload = abi.encodeWithSelector(
      fakeBasicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[TKN]),
      address(coinJoin),
      safeId,
      _collateral,
      _debt
    );

    token.approve(aliceProxy, type(uint256).max);

    // Proxy makes a delegatecall to Malicious BasicAction contract and bypasses the TAX payment
    ODProxy(aliceProxy).execute(address(fakeBasicActions), payload);
    vm.stopPrank();

    ISAFEEngine.SAFE memory safeEngineData = safeEngine.safes(TKN, safeHandler);
    assertEq(
      _collateral, safeEngineData.lockedCollateral - safeEngineData1.lockedCollateral, 'incorrect locked collateral'
    );
    assertEq(_debt, safeEngineData.generatedDebt - safeEngineData1.generatedDebt, 'incorrect generated debt');
  }
}

contract E2ENFTTestFuzzFrontrunning is NFTSetup {
  function test_TimeDelay(uint256 _debt) public {
    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);

    _updateDelays();

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, _debt, aliceProxy);
    vault721.approve(bob, safeId);
    vm.stopPrank();

    vm.warp(block.timestamp + vault721.timeDelay() + 1);

    vm.startPrank(bob);
    vault721.transferFrom(alice, bob, safeId);
    vm.stopPrank();
  }

  function test_TimeDelayRevert(uint256 _debt) public {
    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);

    _updateDelays();

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, _debt, aliceProxy);
    vault721.approve(bob, safeId);
    vm.stopPrank();

    vm.startPrank(bob);
    vm.expectRevert(IVault721.TimeDelayNotOver.selector);
    vault721.transferFrom(alice, bob, safeId);
    vm.stopPrank();
  }

  function test_BlockDelay(uint256 _debt) public {
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters('updateAllowlist', abi.encode(bob, true));
    vm.stopPrank();

    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);

    _updateDelays();

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, _debt, aliceProxy);
    vault721.approve(bob, safeId);
    vm.stopPrank();

    vm.roll(block.number + vault721.blockDelay());

    vm.startPrank(bob);
    vault721.transferFrom(alice, bob, safeId);
    vm.stopPrank();
  }

  function test_BlockDelayRevert(uint256 _debt) public {
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters('updateAllowlist', abi.encode(bob, true));
    vm.stopPrank();

    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);

    _updateDelays();

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, _debt, aliceProxy);
    vault721.approve(bob, safeId);
    vm.stopPrank();

    vm.startPrank(bob);
    vm.expectRevert(IVault721.BlockDelayNotOver.selector);
    vault721.transferFrom(alice, bob, safeId);
    vm.stopPrank();
  }

  function test_UpdatesVaultNfvState(uint256 _debt) public {
    _debt = bound(_debt, 0, MINT_AMOUNT);
    uint256 _collateral = _debt * MULTIPLIER;
    token.mint(alice, _collateral);

    uint256 initBlockNum = block.number;
    uint256 initBlockTime = block.timestamp;

    _updateDelays();
    vm.roll(initBlockNum);
    vm.warp(initBlockTime);

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, _debt, aliceProxy);
    vm.stopPrank();

    IVault721.NFVState memory firstNfvState = vault721.getNfvState(safeId);

    assertEq(firstNfvState.lastBlockNumber, initBlockNum, 'incorrect lastBlockNumber');
    assertEq(firstNfvState.lastBlockTimestamp, initBlockTime, 'incorrect lastBlockTimestamp');

    vm.roll(initBlockNum + 69);
    vm.warp(initBlockTime + 420);

    // should be same as firstNfvState since no new change / update to state
    IVault721.NFVState memory secondNfvState = vault721.getNfvState(safeId);

    assertEq(secondNfvState.lastBlockNumber, initBlockNum, 'incorrect lastBlockNumber');
    assertEq(secondNfvState.lastBlockTimestamp, initBlockTime, 'incorrect lastBlockTimestamp');
  }

  function test_UpdatesVaultNfvState_And_GenerateDebt(uint256 _collateral) public {
    _collateral = bound(_collateral, MINT_AMOUNT / MULTIPLIER, MINT_AMOUNT * MULTIPLIER);
    token.mint(alice, _collateral);

    uint256 initBlockNum = block.number;
    uint256 initBlockTime = block.timestamp;

    _updateDelays();
    vm.roll(initBlockNum);
    vm.warp(initBlockTime);

    vm.startPrank(alice);
    uint256 safeId = openSafe();

    token.approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(TKN, safeId, _collateral, 0, aliceProxy);
    vm.stopPrank();

    IVault721.NFVState memory firstNfvState = vault721.getNfvState(safeId);

    assertEq(firstNfvState.lastBlockNumber, initBlockNum, 'incorrect lastBlockNumber');
    assertEq(firstNfvState.lastBlockTimestamp, initBlockTime, 'incorrect lastBlockTimestamp');

    vm.roll(initBlockNum + 69);
    vm.warp(initBlockTime + 420);

    vm.startPrank(alice);
    genDebt(safeId, _collateral / MULTIPLIER, aliceProxy);
    vm.stopPrank();

    // should be different from firstNfvState since new update to state
    IVault721.NFVState memory secondNfvState = vault721.getNfvState(safeId);

    assertEq(secondNfvState.lastBlockNumber, initBlockNum + 69, 'incorrect lastBlockNumber');
    assertEq(secondNfvState.lastBlockTimestamp, initBlockTime + 420, 'incorrect lastBlockTimestamp');
  }

  function _updateDelays() internal {
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters('timeDelay', abi.encode(5 days));
    vault721.modifyParameters('blockDelay', abi.encode(3));
    vm.stopPrank();
  }
}

contract E2ENFTTestBasicActionsCalls is NFTSetup {
  function test_allowSAFE() public {
    bool ok = true;
    vm.startPrank(alice);
    uint256 safeId = openSafe();

    allowSafe(aliceProxy, safeId, bob, ok);
    vm.stopPrank();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(safeId);

    assertEq(safeManager.safeCan(sData.owner, safeId, sData.nonce, bob), ok, 'incorrect safeCan');
  }

  function test_addAndRemoveSAFE() public {
    vm.startPrank(alice);
    uint256 safeId = openSafe();

    removeSAFE(aliceProxy, safeId);
    addSAFE(aliceProxy, safeId);
    vm.stopPrank();
  }

  /**
   * @dev if the nonce increments, then after each vault transfer
   * all previous allowSAFE calls will be invalidated
   */
  function test_transferFromIncrementsNonce() public {
    vm.startPrank(alice);
    uint256 safeId = openSafe();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(safeId);

    assertEq(sData.nonce, 0, 'nonce not equal');
    vm.warp(block.timestamp + vault721.timeDelay() + 1);
    vm.startPrank(alice);
    vault721.transferFrom(alice, bob, safeId);
    vm.stopPrank();

    sData = safeManager.safeData(safeId);
    assertEq(sData.nonce, 1, 'nonce not equal');
  }
}

contract E2ENFTTestAccessControl is NFTSetup {
  function test_revert_If_UpdateVaultNfvStateWhenNotSafeManager() public {
    vm.startPrank(alice);
    vm.expectRevert(IVault721.NotSafeManager.selector);
    vault721.updateNfvState(1);
    vm.stopPrank();
  }

  function test_revert_If_UpdateAllowlistWhenNotGovernance() public {
    vm.startPrank(alice);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    vault721.modifyParameters('updateAllowlist', abi.encode(alice, true));
    vm.stopPrank();
  }

  function test_revert_If_UpdateAllowlistForZeroAddress() public {
    bytes32 _param = 'updateAllowlist';
    vm.startPrank(vault721.timelockController());
    vm.expectRevert(Assertions.NullAddress.selector);
    vault721.modifyParameters(_param, abi.encode(address(0), true));
    vm.stopPrank();
  }

  function test_revert_If_UpdateTimeDelayWhenNotGovernance() public {
    bytes32 _param = 'updateTimeDelay';
    vm.startPrank(alice);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    vault721.modifyParameters(_param, abi.encode(3 days));
    vm.stopPrank();
  }

  function test_revert_If_UpdateBlockDelayWhenNotGovernance() public {
    bytes32 _param = 'blockDelay';
    vm.startPrank(alice);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    vault721.modifyParameters(_param, abi.encode(3));
    vm.stopPrank();
  }

  function test_UpdateNfvState() public {
    uint256 initTime = block.timestamp;
    uint256 initBlock = block.number;

    vm.prank(alice);
    uint256 safeId = openSafe();

    vm.warp(initTime + 420);
    vm.roll(initBlock + 69);
    vm.prank(address(safeManager));
    vault721.updateNfvState(safeId);

    IVault721.NFVState memory nfvState = vault721.getNfvState(safeId);

    assertEq(nfvState.lastBlockNumber, initBlock + 69, 'incorrect lastBlockNumber');
    assertEq(nfvState.lastBlockTimestamp, initTime + 420, 'incorrect lastBlockTimestamp');
  }

  function test_UpdateAllowlist() public {
    address allowedAddress = address(0x420);
    bytes32 _param = 'updateAllowlist';
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters(_param, abi.encode(allowedAddress, true));
    vm.stopPrank();

    assertEq(vault721.getIsAllowlisted(allowedAddress), true, 'incorrect allowlist');
  }

  function test_UpdateTimeDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters('timeDelay', abi.encode(5 days));
    vm.stopPrank();

    assertEq(vault721.timeDelay(), 5 days, 'timeDelay not met');
  }

  function test_UpdateBlockDelay() public {
    vm.startPrank(vault721.timelockController());
    vault721.modifyParameters('blockDelay', abi.encode(3));
    vm.stopPrank();

    assertEq(vault721.blockDelay(), 3, 'blockDelay not met');
  }
}
