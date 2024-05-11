// SPDX-License-Identifier: GPL-3.0
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

contract E2ESaviourSetup is Common {
  uint256 public constant TREASURY_AMOUNT = 100_000 ether;
  uint256 public constant USER_AMOUNT = 1000 ether;

  ODSaviour public saviour;
  address public treasury;

  address public aliceProxy;
  address public bobProxy;

  mapping(address proxy => uint256 safeId) public vaults;

  function setUp() public virtual override {
    super.setUp();
    treasury = vm.addr(uint256(keccak256('ARB Treasury')));

    IODSaviour.SaviourInit memory _init = _initSaviour(treasury);
    saviour = new ODSaviour(_init);

    _mintTKN(treasury, TREASURY_AMOUNT, address(saviour));
    aliceProxy = _userSetup(vm.addr(uint256(keccak256('Alice'))), USER_AMOUNT, 'AliceProxy');
    bobProxy = _userSetup(vm.addr(uint256(keccak256('Bob'))), USER_AMOUNT, 'BobProxy');
  }

  function _initSaviour(address _saviourTreasury) internal view returns (IODSaviour.SaviourInit memory _init) {
    uint256 len = collateralTypes.length;
    address[] memory tokens = new address[](len);
    for (uint256 i = 0; i < len; i++) {
      tokens[i] = address(collateral[collateralTypes[i]]);
    }
    _init.saviourTreasury = _saviourTreasury;
    _init.protocolGovernor = address(timelockController);
    _init.vault721 = address(vault721);
    _init.oracleRelayer = address(oracleRelayer);
    _init.collateralJoinFactory = address(collateralJoinFactory);
    _init.cTypes = collateralTypes;
    _init.saviourTokens = tokens;
    _init.liquidatorReward = 0;
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
    _token.approve(_okAccount, _amount);
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
  function test_Constants() public view {
    assertEq(saviour.SAVIOUR_TREASURY(), keccak256(abi.encode('SAVIOUR_TREASURY')));
    assertEq(saviour.PROTOCOL(), keccak256(abi.encode('PROTOCOL')));
  }

  function test_Addresses() public view {
    assertEq(saviour.saviourTreasury(), treasury);
    assertEq(saviour.protocolGovernor(), address(timelockController));
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
  function test_Roles() public view {
    assertTrue(IAccessControl(saviour).hasRole(saviour.SAVIOUR_TREASURY(), treasury));
    assertTrue(IAccessControl(saviour).hasRole(saviour.PROTOCOL(), address(timelockController)));
    assertTrue(IAccessControl(saviour).hasRole(saviour.PROTOCOL(), address(liquidationEngine)));
  }

  function test_AddCType(bytes32 _cType, address _tokenAddress) public {
    vm.startPrank(treasury);
    saviour.addCType(_cType, _tokenAddress);
    assertTrue(saviour.cType(_cType) == _tokenAddress);
  }

  function test_AddCTypeRevert(address _attacker, bytes32 _cType, address _tokenAddress) public {
    vm.assume(_attacker != treasury);
    vm.startPrank(_attacker);
    vm.expectRevert();
    saviour.addCType(_cType, _tokenAddress);
  }

  function test_setLiquidatorReward(uint256 _rewardA, uint256 _rewardB) public {
    vm.prank(address(timelockController));
    saviour.setLiquidatorReward(_rewardA);
    assertTrue(saviour.liquidatorReward() == _rewardA);

    vm.prank(address(liquidationEngine));
    saviour.setLiquidatorReward(_rewardB);
    assertTrue(saviour.liquidatorReward() == _rewardB);
  }

  function test_setLiquidatorRewardRevert(address _attacker, uint256 _reward) public {
    vm.assume(_attacker != address(timelockController) && _attacker != address(liquidationEngine));
    vm.startPrank(_attacker);
    vm.expectRevert();
    saviour.setLiquidatorReward(_reward);
  }

  function test_SetVaultStatus(uint256 _vaultId, bool _enabled) public {
    vm.startPrank(treasury);
    saviour.setVaultStatus(_vaultId, _enabled);
    assertTrue(saviour.isEnabled(_vaultId) == _enabled);
  }

  function test_SetVaultStatusRevert(address _attacker, uint256 _vaultId, bool _enabled) public {
    vm.assume(_attacker != treasury);
    vm.startPrank(_attacker);
    vm.expectRevert();
    saviour.setVaultStatus(_vaultId, _enabled);
  }

  function test_SaveSafe(bytes32 _cType, address _safe) public {
    vm.prank(address(liquidationEngine));
    saviour.saveSAFE(address(liquidationEngine), _cType, _safe);
  }

  function test_SaveSafeRevert(bytes32 _cType, address _safe) public {
    vm.prank(address(timelockController));
    vm.expectRevert();
    saviour.saveSAFE(address(timelockController), _cType, _safe);
  }

  function test_SaveSafeRevert(address _liquidator, bytes32 _cType, address _safe) public {
    vm.assume(_liquidator != address(timelockController) && _liquidator != address(liquidationEngine));
    vm.prank(address(timelockController));
    vm.expectRevert();
    saviour.saveSAFE(_liquidator, _cType, _safe);

    vm.prank(address(liquidationEngine));
    vm.expectRevert();
    saviour.saveSAFE(_liquidator, _cType, _safe);
  }

  function test_SaveSafeRevert(address _attacker, address _liquidator, bytes32 _cType, address _safe) public {
    vm.assume(
      _attacker != address(timelockController) && _attacker != address(liquidationEngine) && _attacker != _liquidator
    );
    vm.startPrank(_attacker);
    vm.expectRevert();
    saviour.saveSAFE(_liquidator, _cType, _safe);
  }
}

/// TODO in testParams safety ratio is the same as liquidation ratio - change ratios

/// TODO change collateral value to create condition for liquidation

contract E2ESaviourTestSaveSafe is E2ESaviourSetup {
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

  uint256 public oracleRead; // WAD
  uint256 public liquidationCRatio; // RAY
  uint256 public safetyCRatio; // RAY
  uint256 public accumulatedRate; // RAY

  uint256 public wadSafetyCRatio;
  uint256 public wadLiquidationCRatio;
  uint256 public wadAccumulatedRate;

  function setUp() public override {
    super.setUp();
    aliceNFV = vault721.getNfvState(vaults[aliceProxy]);
    bobNFV = vault721.getNfvState(vaults[bobProxy]);

    cTypeData = safeEngine.cData(TKN);
    accumulatedRate = cTypeData.accumulatedRate;
    oracleParams = oracleRelayer.cParams(TKN);
    liquidationCRatio = oracleParams.liquidationCRatio;
    safetyCRatio = oracleParams.safetyCRatio;
    oracle = oracleParams.oracle;
    oracleRead = oracle.read();

    /// @notice WAD conversions
    wadAccumulatedRate = accumulatedRate / RAY_WAD_DIFF;
    wadLiquidationCRatio = liquidationCRatio / RAY_WAD_DIFF;
    wadSafetyCRatio = safetyCRatio / RAY_WAD_DIFF;

    _depositCollatAndGenDebt(vaults[aliceProxy], DEPOSIT, MINT, aliceProxy);
    _depositCollatAndGenDebt(vaults[bobProxy], DEPOSIT, MINT, bobProxy);
  }

  /**
   * @dev Tests
   */
  function test_EmitLogs() public {
    /// @notice RAY format
    emit log_named_uint('Oracle Read - [to RAY]:', oracleRead * RAY_WAD_DIFF);
    emit log_named_uint('Accumulated Rate [RAY]:', accumulatedRate);
    emit log_named_uint('SafetyCRatio TKN [RAY]:', safetyCRatio);
    emit log_named_uint('LiquidCRatio TKN [RAY]:', liquidationCRatio);

    /// @notice WAD format
    emit log_named_uint('Oracle Read ------- [WAD]:', oracleRead);
    emit log_named_uint('Accumulated Rate [to WAD]:', wadAccumulatedRate);
    emit log_named_uint('SafetyCRatio TKN [to WAD]:', wadSafetyCRatio);
    emit log_named_uint('LiquidCRatio TKN [to WAD]:', wadLiquidationCRatio);
    assertTrue(wadSafetyCRatio / oracleRead > 0);

    uint256 percentOracleRead = _toFixedPointPercent(oracleRead);
    uint256 percentSafetyCRatio = _toFixedPointPercent(wadSafetyCRatio);
    uint256 percentLiquidationCRatio = _toFixedPointPercent(wadLiquidationCRatio);

    /// @notice Fixed point 2-decimal format (nftRenderer format)
    emit log_named_uint('Oracle Read ---- [to %]:', percentOracleRead);
    emit log_named_uint('SafetyCRatio TKN [to %]:', percentSafetyCRatio);
    emit log_named_uint('LiquidCRatio TKN [to %]:', percentLiquidationCRatio);
    assertTrue(percentSafetyCRatio / percentOracleRead > 0);
  }

  function test_SetUp() public view {
    (uint256 _collateral, uint256 _debt) = saviour.getCurrentCollateralAndDebt(TKN, aliceNFV.safeHandler);
    assertEq(_collateral, DEPOSIT);
    assertEq(_debt, MINT);
  }

  function test_isAboveRatio() public {
    (uint256 _riskRatio, uint256 _percentOverSafety) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio', _riskRatio);
    emit log_named_uint('Percent Above', _percentOverSafety);
  }

  function test_increaseRisk1() public {
    (uint256 _riskRatioBefore, uint256 _percentOverSafetyBefore) = _readRisk(aliceNFV.safeHandler);
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 0.001 ether, aliceProxy);
    (uint256 _riskRatioAfter, uint256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio + 0.001 ether', _riskRatioAfter);
    emit log_named_uint('Percent Above + 0.001 ether', _percentOverSafetyAfter);
  }

  function test_increaseRisk2() public {
    (uint256 _riskRatioBefore, uint256 _percentOverSafetyBefore) = _readRisk(aliceNFV.safeHandler);
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 1 ether, aliceProxy);
    (uint256 _riskRatioAfter, uint256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio + 1 ether', _riskRatioAfter);
    emit log_named_uint('Percent Above + 1 ether', _percentOverSafetyAfter);
  }

  function test_increaseRisk3() public {
    (uint256 _riskRatioBefore, uint256 _percentOverSafetyBefore) = _readRisk(aliceNFV.safeHandler);
    _depositCollatAndGenDebt(vaults[aliceProxy], 0, 5 ether, aliceProxy);
    (uint256 _riskRatioAfter, uint256 _percentOverSafetyAfter) = _readRisk(aliceNFV.safeHandler);
    emit log_named_uint('Vault   Ratio + 5 ether', _riskRatioAfter);
    emit log_named_uint('Percent Above + 5 ether', _percentOverSafetyAfter);
  }

  /**
   * @dev Helper functions
   */
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

  function _readRisk(address _safeHandler) internal returns (uint256 _riskRatio, uint256 _percentOverSafety) {
    (uint256 _collateral, uint256 _debt) = saviour.getCurrentCollateralAndDebt(TKN, _safeHandler);
    _riskRatio = _collateral.wmul(oracle.read()).wdiv(_debt.wmul(accumulatedRate)) / (RAY_WAD_DIFF / TWO_DECIMAL_OFFSET);
    _percentOverSafety = _riskRatio - _toFixedPointPercent(wadSafetyCRatio);
  }
}
