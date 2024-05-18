// SPDX-License-Identifier GPL-3.0
pragma solidity 0.8.20;

import {AccessControl, IAccessControl} from '@openzeppelin/access/AccessControl.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {Common, COLLAT, DEBT, TKN} from '@test/e2e/Common.t.sol';
import {ODSaviour, IODSaviour} from '@test/e2e/e2eSaviour/contracts/ODSaviour.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {Math} from '@libraries/Math.sol';
import {DelayedOracleForTest} from '@test/mocks/DelayedOracleForTest.sol';
import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';

contract E2ESaviourSetup is Common {
  uint256 public constant TREASURY_AMOUNT = 1_000_000_000_000_000_000_000_000_000 ether;
  uint256 public constant PROTOCOL_AMOUNT = 1_000_000_000 ether;
  uint256 public constant USER_AMOUNT = 1000 ether;

  ODSaviour public saviour;
  address public treasury;

  address public aliceProxy;
  address public bobProxy;
  address public deployerProxy;

  mapping(address proxy => uint256 safeId) public vaults;

  function setUp() public virtual override {
    super.setUp();
    treasury = vm.addr(uint256(keccak256('ARB Treasury')));

    IODSaviour.SaviourInit memory _init = IODSaviour.SaviourInit({
      vault721: address(vault721),
      oracleRelayer: address(oracleRelayer),
      collateralJoinFactory: address(collateralJoinFactory)
    });

    saviour = new ODSaviour(_init);
    saviour.modifyParameters('saviourTreasury', abi.encode(treasury));
    saviour.initializeCollateralType(TKN, abi.encode(address(collateral[TKN])));

    _mintTKN(treasury, TREASURY_AMOUNT, address(saviour));
    aliceProxy = _userSetup(alice, USER_AMOUNT, 'AliceProxy');
    bobProxy = _userSetup(bob, USER_AMOUNT, 'BobProxy');
    deployerProxy = _userSetup(deployer, PROTOCOL_AMOUNT, 'DeployerProxy');
  }

  function _userSetup(address _user, uint256 _amount, string memory _name) internal returns (address _proxy) {
    _proxy = _deployOrFind(_user);
    _mintTKN(_user, _amount, _proxy);
    vm.label(_proxy, _name);
    vm.prank(_proxy);
    vaults[_proxy] = safeManager.openSAFE(TKN, _proxy);
  }

  function _mintTKN(address _account, uint256 _amount, address _okAccount) internal {
    vm.startPrank(_account);
    ERC20ForTest _token = ERC20ForTest(address(collateral[TKN]));
    _token.mint(_amount);
    if (_okAccount != address(0)) {
      _token.approve(_okAccount, _amount);
    }
    vm.stopPrank();
  }

  function _deployOrFind(address _owner) internal returns (address) {
    address proxy = vault721.getProxy(_owner);
    if (proxy == address(0)) {
      return address(vault721.build(_owner));
    } else {
      return proxy;
    }
  }
}

contract E2ESaviourTestSetup is E2ESaviourSetup {
  function test_Addresses() public view {
    assertEq(saviour.saviourTreasury(), treasury);
    assertEq(saviour.liquidationEngine(), address(liquidationEngine));
  }

  function test_Contracts() public view {
    assertTrue(saviour.vault721() == vault721);
    assertTrue(saviour.oracleRelayer() == oracleRelayer);
    assertTrue(saviour.safeManager() == safeManager);
    assertTrue(saviour.safeEngine() == safeEngine);
    assertTrue(saviour.collateralJoinFactory() == collateralJoinFactory);
  }
}

contract E2ESaviourTestAccessControl is E2ESaviourSetup {
  modifier notZero(bytes32 _b, address _a) {
    vm.assume(_b != bytes32(0));
    vm.assume(_a != address(0));
    _;
  }

  function test_roles() public view {
    assertTrue(IAuthorizable(saviour).authorizedAccounts(treasury));
    assertTrue(IAuthorizable(saviour).authorizedAccounts(address(this)));
  }

  function test_initCType(bytes32 _cType, address _tokenAddress) public notZero(_cType, _tokenAddress) {
    vm.prank(treasury);
    saviour.initializeCollateralType(_cType, abi.encode(_tokenAddress));
    assertTrue(saviour.cType(_cType) == _tokenAddress);
  }

  function test_initCTypeRevert(
    address _attacker,
    bytes32 _cType,
    address _tokenAddress
  ) public notZero(_cType, _tokenAddress) {
    vm.assume(_attacker != treasury);
    vm.prank(_attacker);
    vm.expectRevert();
    saviour.initializeCollateralType(_cType, abi.encode(_tokenAddress));
  }

  function test_setLiquidatorReward(uint256 _reward) public {
    saviour.modifyParameters('liquidatorReward', abi.encode(_reward));
    assertTrue(saviour.liquidatorReward() == _reward);
  }

  function test_setLiquidatorRewardRevert(address _attacker, uint256 _reward) public {
    vm.assume(_attacker != address(this));
    vm.prank(_attacker);
    vm.expectRevert();
    saviour.modifyParameters('liquidatorReward', abi.encode(_reward));
  }

  function test_modifyParams() public {
    uint256 _vaultId = 1;
    assertFalse(saviour.isEnabled(_vaultId));
    saviour.modifyParameters('setVaultStatus', abi.encode(_vaultId, true));
    assertTrue(saviour.isEnabled(_vaultId));
  }

  function test_modifyParams(bool _enabled) public {
    uint256 _vaultId = 2;
    saviour.modifyParameters('setVaultStatus', abi.encode(_vaultId, _enabled));
    assertTrue(saviour.isEnabled(_vaultId) == _enabled);
  }

  function test_modifyParamsRevert(address _attacker, uint256 _vaultId, bool _enabled) public {
    vm.assume(_attacker != address(this));
    vm.prank(_attacker);
    vm.expectRevert();
    saviour.modifyParameters('setVaultStatus', abi.encode(_vaultId, _enabled));
  }

  function test_saveSafe(bytes32 _cType, address _safe) public {
    saviour.modifyParameters('setVaultStatus', abi.encode(1, true));
    vm.prank(address(liquidationEngine));
    (bool _ok,,) = saviour.saveSAFE(address(liquidationEngine), _cType, _safe);
    assertTrue(_ok);
  }

  function test_SaveSafe(address _liquidator, bytes32 _cType, address _safe) public {
    vm.prank(address(liquidationEngine));
    (bool _ok,,) = saviour.saveSAFE(_liquidator, _cType, _safe);
    assertTrue(_ok);
  }

  function test_saveSafeRevert(address _attacker, bytes32 _cType, address _safe) public {
    vm.assume(_attacker != address(liquidationEngine));
    vm.prank(_attacker);
    vm.expectRevert();
    saviour.saveSAFE(address(liquidationEngine), _cType, _safe);
  }
}

/// TODO in testParams safety ratio is the same as liquidation ratio - change ratios
contract E2ESaviourTestRiskSetup is E2ESaviourSetup {
  using Math for uint256;

  uint256 public constant RAD = 1e45;
  uint256 public constant RAY = 1e27;
  uint256 public constant WAD = 1e18;
  uint256 public constant RAY_WAD_DIFF = RAY / WAD;
  uint256 public constant TWO_DECIMAL_OFFSET = 1e2;

  uint256 public constant DEPOSIT = 100 ether;
  uint256 public constant MINT = DEPOSIT / 3 * 2;

  IVault721.NFVState public aliceNFV;
  IVault721.NFVState public bobNFV;

  ISAFEEngine.SAFEEngineCollateralData public cTypeData;
  IOracleRelayer.OracleRelayerCollateralParams public oracleParams;
  IDelayedOracle public oracle;
  DelayedOracleForTest public tknOracle;

  uint256 public oracleRead; // WAD
  uint256 public liquidationCRatio; // RAY
  uint256 public safetyCRatio; // RAY
  uint256 public accumulatedRate; // RAY
  uint256 public liquidationPrice; // RAY

  function setUp() public virtual override {
    super.setUp();
    tknOracle = DelayedOracleForTest(address(delayedOracle[TKN]));
    _setAndRefreshData();
    _depositCollatAndGenDebt(vaults[aliceProxy], DEPOSIT, MINT, aliceProxy);
    _depositCollatAndGenDebt(vaults[bobProxy], DEPOSIT, MINT, bobProxy);
    _depositCollatAndGenDebt(vaults[deployerProxy], PROTOCOL_AMOUNT, MINT, deployerProxy);
  }

  /**
   * @dev Helper functions
   */
  function _setAndRefreshData() internal {
    aliceNFV = vault721.getNfvState(vaults[aliceProxy]);
    bobNFV = vault721.getNfvState(vaults[bobProxy]);
    cTypeData = safeEngine.cData(TKN);
    liquidationPrice = cTypeData.liquidationPrice;
    accumulatedRate = cTypeData.accumulatedRate;
    oracleParams = oracleRelayer.cParams(TKN);
    liquidationCRatio = oracleParams.liquidationCRatio;
    safetyCRatio = oracleParams.safetyCRatio;
    oracle = oracleParams.oracle;
    oracleRead = oracle.read();
  }

  function _depositCollatAndGenDebt(uint256 _safeId, uint256 _collatAmount, uint256 _deltaWad, address _proxy) internal {
    vm.startPrank(ODProxy(_proxy).OWNER());
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[TKN]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
    vm.stopPrank();
  }

  function _toFixedPointPercent(uint256 _wad) internal pure returns (uint256 _fixedPtPercent) {
    _fixedPtPercent = _wad / (WAD / TWO_DECIMAL_OFFSET);
  }

  function _readRisk(address _safeHandler) internal view returns (uint256 _riskRatio, int256 _percentOverSafety) {
    (uint256 _collateral, uint256 _debt) = saviour.getCurrentCollateralAndDebt(TKN, _safeHandler);
    _riskRatio = _collateral.wmul(oracle.read()).wdiv(_debt.wmul(accumulatedRate)) / (RAY_WAD_DIFF / TWO_DECIMAL_OFFSET);
    unchecked {
      _percentOverSafety = int256(_riskRatio) - int256((safetyCRatio / RAY_WAD_DIFF) / (WAD / TWO_DECIMAL_OFFSET));
    }
  }
}

contract E2ESaviourTestRisk is E2ESaviourTestRiskSetup {
  function test_EmitLogs() public {
    /// @notice RAY format
    emit log_named_uint('Oracle Read - [to RAY]', oracleRead * RAY_WAD_DIFF);
    emit log_named_uint('Accumulated Rate [RAY]', accumulatedRate);
    emit log_named_uint('SafetyCRatio TKN [RAY]', safetyCRatio);
    emit log_named_uint('LiquidCRatio TKN [RAY]', liquidationCRatio);

    uint256 percentOracleRead = _toFixedPointPercent(oracleRead);
    uint256 percentSafetyCRatio = _toFixedPointPercent(safetyCRatio / RAY_WAD_DIFF);
    uint256 percentLiquidationCRatio = _toFixedPointPercent(liquidationCRatio / RAY_WAD_DIFF);

    /// @notice Fixed point 2-decimal format (nftRenderer format)
    emit log_named_uint('Oracle Read ---- [to %]', percentOracleRead);
    emit log_named_uint('SafetyCRatio TKN [to %]', percentSafetyCRatio);
    emit log_named_uint('LiquidCRatio TKN [to %]', percentLiquidationCRatio);
    assertTrue(percentSafetyCRatio / percentOracleRead > 0);
  }

  function test_oracle() public view {
    IOracleRelayer.OracleRelayerCollateralParams memory oracleParams = oracleRelayer.cParams(TKN);
    IDelayedOracle oracle = oracleParams.oracle;
    assertEq(address(tknOracle), address(oracle));
  }

  function test_setUp() public view {
    (uint256 _collateral, uint256 _debt) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    assertEq(_collateral, DEPOSIT);
    assertEq(_debt, MINT);
  }

  function test_isAboveRatio() public {
    (uint256 _riskRatio, int256 _percentOverSafety) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio', _riskRatio);
    emit log_named_int('Percent Above', _percentOverSafety);
  }

  function test_increaseRisk1() public {
    (uint256 _riskRatioBefore, int256 _percentOverSafetyBefore) = _readRisk(aliceNFV.safeHandler);
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 0.001 ether, aliceProxy);
    (uint256 _riskRatioAfter, int256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio + 0.001 ether', _riskRatioAfter);
    emit log_named_int('Percent Above + 0.001 ether', _percentOverSafetyAfter);
  }

  function test_increaseRisk2() public {
    (uint256 _riskRatioBefore, int256 _percentOverSafetyBefore) = _readRisk(aliceNFV.safeHandler);
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 1 ether, aliceProxy);
    (uint256 _riskRatioAfter, int256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio + 1 ether', _riskRatioAfter);
    emit log_named_int('Percent Above + 1 ether', _percentOverSafetyAfter);
  }

  function test_increaseRisk3() public {
    (uint256 _riskRatioBefore, int256 _percentOverSafetyBefore) = _readRisk(aliceNFV.safeHandler);
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 5 ether, aliceProxy);
    (uint256 _riskRatioAfter, int256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio + 5 ether', _riskRatioAfter);
    emit log_named_int('Percent Above + 5 ether', _percentOverSafetyAfter);
  }

  function test_triggerLiquidationScenario() public {
    (uint256 _riskRatioBefore, int256 _percentOverSafetyBefore) = _readRisk(aliceNFV.safeHandler);
    uint256 tknPriceBefore = tknOracle.read();
    uint256 systemCoinPrice = systemCoinOracle.read();
    tknOracle.setPriceAndValidity(tknPriceBefore - 0.05 ether, true);
    uint256 tknPriceAfter = tknOracle.read();
    (uint256 _riskRatioAfter, int256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    assertTrue(_riskRatioBefore > _riskRatioAfter);
  }
}

contract E2ESaviourTestLiquidateSetup is E2ESaviourTestRiskSetup {
  function setUp() public virtual override {
    super.setUp();
    // increase user's vault risk
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 5 ether, aliceProxy);
    _depositCollatAndGenDebt(vaults[bobProxy], 0, 5 ether, bobProxy);
    // devalue collateral TKN
    tknOracle.setPriceAndValidity(tknOracle.read() - 0.2 ether, true);
    // trigger update of collateral devaluation in safeEngine.cData.liquidationPrice
    _setAndRefreshData();
    oracleRelayer.updateCollateralPrice(TKN);
    _setAndRefreshData();
  }
}

contract E2ESaviourTestLiquidate is E2ESaviourTestLiquidateSetup {
  function test_belowSafety() public {
    (uint256 _riskRatioAfter, int256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault  Risk  Ratio', _riskRatioAfter);
    emit log_named_int('Percent Difference', _percentOverSafetyAfter);
    // collateralization ratio is negative (under-collateralized)
    assertTrue(0 > _percentOverSafetyAfter);
  }

  function test_safeNotSafe() public {
    (uint256 _collateral, uint256 _debt) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    uint256 collateralValue = _collateral * liquidationPrice;
    uint256 debtValue = _debt * accumulatedRate;
    emit log_named_uint('Collateral X LiquiPrice', collateralValue);
    emit log_named_uint('Debt X AccumulatedPrice', debtValue);
    assertTrue(collateralValue < debtValue);
  }

  function test_liquidateUnprotectedSafes() public {
    liquidationEngine.liquidateSAFE(TKN, aliceNFV.safeHandler);
    liquidationEngine.liquidateSAFE(TKN, bobNFV.safeHandler);
    (uint256 _collateralA, uint256 _debtA) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    (uint256 _collateralB, uint256 _debtB) = saviour.getCurrentCollateralAndDebt(TKN, bobNFV.safeHandler);
    assertTrue(_collateralA == 0 && _debtA == 0);
    assertTrue(_collateralB == 0 && _debtB == 0);
  }
}

contract E2ESaviourTestLiquidateAndSave is E2ESaviourTestLiquidateSetup {
  ERC20ForTest public token;

  function setUp() public virtual override {
    super.setUp();
    token = ERC20ForTest(saviour.cType(TKN));

    // Protocol DAO to connect saviour
    vm.prank(liquidationEngine.authorizedAccounts()[0]);
    liquidationEngine.connectSAFESaviour(address(saviour));

    // Treasury to approve select protocol vaults as eligible for saving
    saviour.modifyParameters('setVaultStatus', abi.encode(vaults[aliceProxy], true));

    bytes memory payloadAllow = abi.encodeWithSelector(
      basicActions.allowSAFE.selector, address(safeManager), vaults[aliceProxy], address(saviour), true
    );
    // Approve saviour as safe handler
    vm.prank(alice);
    ODProxy(aliceProxy).execute(address(basicActions), payloadAllow);

    bytes memory payloadProtect = abi.encodeWithSelector(
      basicActions.protectSAFE.selector, address(safeManager), vaults[aliceProxy], address(saviour)
    );
    // Proxy to elect saviour to protect vault
    vm.prank(alice);
    ODProxy(aliceProxy).execute(address(basicActions), payloadProtect);

    _setAndRefreshData();
  }

  function test_tokenBals() public view {
    assertEq(token.balanceOf(treasury), TREASURY_AMOUNT);
    assertEq(token.balanceOf(address(saviour)), 0);
    assertEq(token.allowance(treasury, address(saviour)), TREASURY_AMOUNT);
  }

  function test_enabledVault() public view {
    assertTrue(saviour.isEnabled(vaults[aliceProxy]));
  }

  function test_disabledVault() public view {
    assertFalse(saviour.isEnabled(vaults[bobProxy]));
  }

  function test_protectSafe() public view {
    address chosenSaviour = liquidationEngine.chosenSAFESaviour(TKN, aliceNFV.safeHandler);
    assertTrue(address(saviour) == chosenSaviour);
  }

  function test_failToProtectSafe() public {
    vm.prank(bobProxy);
    vm.expectRevert();
    liquidationEngine.protectSAFE(TKN, bobNFV.safeHandler, address(saviour));
  }

  function test_liquidateProtectedSafe() public {
    (uint256 _collateralA, uint256 _debtA) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    assertTrue(_collateralA > 0 && _debtA > 0);
    liquidationEngine.liquidateSAFE(TKN, aliceNFV.safeHandler);
    (uint256 _collateralB, uint256 _debtB) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    assertTrue(_collateralB > _collateralA && _debtB == _debtA);
  }

  function test_liquidateUnprotectedSafe() public {
    (uint256 _collateralA, uint256 _debtA) = saviour.getCurrentCollateralAndDebt(TKN, bobNFV.safeHandler);
    assertTrue(_collateralA > 0 && _debtA > 0);
    liquidationEngine.liquidateSAFE(TKN, bobNFV.safeHandler);
    (uint256 _collateralB, uint256 _debtB) = saviour.getCurrentCollateralAndDebt(TKN, bobNFV.safeHandler);
    assertTrue(_collateralB == 0 && _debtB == 0);
  }
}

/// todo clean up and refactor to remove duplicate code in other setups
contract E2ESaviourTestFuzz is E2ESaviourTestRiskSetup {
  using Math for uint256;

  ERC20ForTest public token;

  function setUp() public virtual override {
    super.setUp();
    token = ERC20ForTest(saviour.cType(TKN));

    // increase user's vault risk
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 5 ether, aliceProxy);
    _depositCollatAndGenDebt(vaults[bobProxy], 0, 5 ether, bobProxy);

    // Protocol DAO to connect saviour
    vm.prank(liquidationEngine.authorizedAccounts()[0]);
    liquidationEngine.connectSAFESaviour(address(saviour));

    // Treasury to approve select protocol vaults as eligible for saving
    saviour.modifyParameters('setVaultStatus', abi.encode(vaults[aliceProxy], true));

    bytes memory payloadAllow = abi.encodeWithSelector(
      basicActions.allowSAFE.selector, address(safeManager), vaults[aliceProxy], address(saviour), true
    );
    // Approve saviour as safe handler
    vm.prank(alice);
    ODProxy(aliceProxy).execute(address(basicActions), payloadAllow);

    bytes memory payloadProtect = abi.encodeWithSelector(
      basicActions.protectSAFE.selector, address(safeManager), vaults[aliceProxy], address(saviour)
    );
    // Proxy to elect saviour to protect vault
    vm.prank(alice);
    ODProxy(aliceProxy).execute(address(basicActions), payloadProtect);

    _setAndRefreshData();
  }

  function _devalueCollateral(uint256 _devaluation) internal {
    uint256 _tknPrice = tknOracle.read();
    emit log_named_uint('TKN   Price', _tknPrice);
    emit log_named_uint('DEVAL Price', _devaluation);
    tknOracle.setPriceAndValidity(_tknPrice - _devaluation, true);
    _setAndRefreshData();
    oracleRelayer.updateCollateralPrice(TKN);
    _setAndRefreshData();
  }

  function test_algorithm(uint256 _devaluation) public {
    _devaluation = bound(_devaluation, 0.1 ether, 1 ether - 1);
    _devalueCollateral(_devaluation);

    ISAFEEngine.SAFEEngineCollateralData memory _safeEngCData = safeEngine.cData(TKN);
    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(TKN, aliceNFV.safeHandler);

    (uint256 _currCollateral, uint256 _currDebt) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    uint256 _accumulatedRate = _safeEngCData.accumulatedRate;
    uint256 _liquidationPrice = _safeEngCData.liquidationPrice;
    uint256 _safetyPrice = _safeEngCData.safetyPrice;

    uint256 _collatXliqPrice = _currCollateral.wmul(_liquidationPrice);
    uint256 _debtXaccumuRate = _currDebt.wmul(_accumulatedRate);

    if (_collatXliqPrice < _debtXaccumuRate) {
      uint256 _reqAmount = (_debtXaccumuRate - _collatXliqPrice).wdiv(_safetyPrice);
      uint256 _newCollatXliqPrice = (_currCollateral + _reqAmount).wmul(_liquidationPrice);

      assertTrue(_newCollatXliqPrice > _debtXaccumuRate);
    }
  }

  function test_liquidateProtectedSafe(uint256 _devaluation) public {
    _devaluation = bound(_devaluation, 1, 1 ether - 1);
    (uint256 _collateralA, uint256 _debtA) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    assertTrue(_collateralA > 0 && _debtA > 0);
    assertTrue((_collateralA * liquidationPrice) >= (_debtA * accumulatedRate));

    _devalueCollateral(_devaluation);
    (uint256 _collateralB, uint256 _debtB) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    if (liquidationPrice != 0 && (_collateralB * liquidationPrice) < (_debtB * accumulatedRate)) {
      liquidationEngine.liquidateSAFE(TKN, aliceNFV.safeHandler);
    }
    (uint256 _collateralC, uint256 _debtC) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    assertTrue(_collateralC >= _collateralA);
    assertEq(_debtC, _debtA);
  }

  function test_liquidateUnprotectedSafe(uint256 _devaluation) public {
    _devaluation = bound(_devaluation, 1, 1 ether - 1);
    uint256 _collateralC;
    uint256 _debtC;

    (uint256 _collateralA, uint256 _debtA) = saviour.getCurrentCollateralAndDebt(TKN, bobNFV.safeHandler);
    assertTrue(_collateralA > 0 && _debtA > 0);
    assertTrue((_collateralA * liquidationPrice) >= (_debtA * accumulatedRate));

    _devalueCollateral(_devaluation);
    (uint256 _collateralB, uint256 _debtB) = saviour.getCurrentCollateralAndDebt(TKN, bobNFV.safeHandler);

    if (liquidationPrice != 0 && (_collateralB * liquidationPrice) < (_debtB * accumulatedRate)) {
      liquidationEngine.liquidateSAFE(TKN, bobNFV.safeHandler);

      (_collateralC, _debtC) = saviour.getCurrentCollateralAndDebt(TKN, bobNFV.safeHandler);
      assertTrue(_collateralC == 0 && _debtC == 0);
    } else {
      (_collateralC, _debtC) = saviour.getCurrentCollateralAndDebt(TKN, bobNFV.safeHandler);
      assertTrue(_collateralC == _collateralA && _debtC == _debtA);
    }
  }
}
