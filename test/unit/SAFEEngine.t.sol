// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {SAFEEngineForTest, ISAFEEngine} from '@test/mocks/SAFEEngineForTest.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  // Test addresses
  address deployer = newAddress();
  address safe = newAddress();
  address collateralSource = newAddress();
  address debtDestination = newAddress();
  address src = newAddress();
  address dst = newAddress();
  address account = newAddress();
  address coinDestination = newAddress();
  address surplusDst = newAddress();

  ISAFEEngine.SAFEEngineParams safeEngineParams =
    ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});

  // Test collateral type
  bytes32 collateralType = 'collateralTest';

  ISAFEEngine safeEngine;

  function setUp() public virtual {
    vm.prank(deployer);

    safeEngine = new SAFEEngineForTest(safeEngineParams);
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
    vm.stopPrank();
  }

  function _mockTokenCollateral(bytes32 _cType, address _account, uint256 _wad) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.tokenCollateral.selector).with_key(_cType).with_key(_account)
      .checked_write(_wad);
  }

  function _mockCoinBalance(address _account, uint256 _rad) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.coinBalance.selector).with_key(_account).checked_write(_rad);
  }

  function _mockSafeData(bytes32 _cType, address _safe, ISAFEEngine.SAFE memory _safeData) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safes.selector).with_key(_cType).with_key(_safe).depth(0)
      .checked_write(_safeData.lockedCollateral);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safes.selector).with_key(_cType).with_key(_safe).depth(1)
      .checked_write(_safeData.generatedDebt);
  }

  function _mockCollateralList(bytes32 _cType) internal {
    SAFEEngineForTest(address(safeEngine)).addToCollateralList(_cType);
  }

  function _mockCollateralType(bytes32 _cType, ISAFEEngine.SAFEEngineCollateralData memory _cData) internal {
    // cData
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(0).checked_write(
      _cData.debtAmount
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(1).checked_write(
      _cData.lockedAmount
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(2).checked_write(
      _cData.accumulatedRate
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(3).checked_write(
      _cData.safetyPrice
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(4).checked_write(
      _cData.liquidationPrice
    );
  }

  function _mockCollateralParams(bytes32 _cType, ISAFEEngine.SAFEEngineCollateralParams memory _cParams) internal {
    // cParams
    _mockDebtCeiling(_cType, _cParams.debtCeiling);
    _mockDebtFloor(_cType, _cParams.debtFloor);
  }

  function _mockDebtCeiling(bytes32 _cType, uint256 _debtCeiling) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cParams.selector).with_key(_cType).depth(0).checked_write(
      _debtCeiling
    );
  }

  function _mockDebtFloor(bytes32 _cType, uint256 _debtFloor) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cParams.selector).with_key(_cType).depth(1).checked_write(
      _debtFloor
    );
  }

  function _mockParams(ISAFEEngine.SAFEEngineParams memory _params) internal {
    _mockSafeDebtCeiling(_params.safeDebtCeiling);
    _mockGlobalDebtCeiling(_params.globalDebtCeiling);
  }

  function _mockSafeDebtCeiling(uint256 _safeDebtCeiling) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.params.selector).depth(0).checked_write(_safeDebtCeiling);
  }

  function _mockGlobalDebtCeiling(uint256 _globalDebtCeiling) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.params.selector).depth(1).checked_write(_globalDebtCeiling);
  }

  function _mockGlobalUnbackedDebt(uint256 _globalUnbackedDebt) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.globalUnbackedDebt.selector).checked_write(_globalUnbackedDebt);
  }

  function _mockDebtBalance(address _account, uint256 _rad) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.debtBalance.selector).with_key(_account).checked_write(_rad);
  }

  function _mockGlobalDebt(uint256 _globalDebt) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.globalDebt.selector).checked_write(_globalDebt);
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    stdstore.target(address(safeEngine)).sig(IDisableable.contractEnabled.selector).checked_write(_contractEnabled);
  }

  function _mockCanModifySafe(address _safe, address _account, bool _canModifySafe) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safeRights.selector).with_key(_safe).with_key(_account)
      .checked_write(_canModifySafe);
  }
}

contract Unit_SAFEEngine_Constructor is Base {
  event AddAuthorization(address _account);
  event ModifyParameters(bytes32 indexed _parameter, bytes32 indexed _collateral, bytes _data);

  function test_Set_AuthorizedAccounts() public {
    assertEq(IAuthorizable(address(safeEngine)).authorizedAccounts(deployer), true);
  }

  function test_Set_SafeDebtCeiling() public {
    uint256 _safeDebtCeiling = safeEngine.params().safeDebtCeiling;
    assertEq(_safeDebtCeiling, type(uint256).max);
  }

  function test_Set_ContractEnabled() public {
    assertEq(safeEngine.contractEnabled(), true);
  }

  function test_Emit_AddAuthorization() public {
    vm.expectEmit();
    emit AddAuthorization(deployer);
    vm.prank(deployer);
    safeEngine = new SAFEEngineForTest(safeEngineParams);
  }

  function test_Set_SAFEEngine_Params(ISAFEEngine.SAFEEngineParams memory _safeEngineParams) public {
    safeEngine = new SAFEEngineForTest(_safeEngineParams);
    assertEq(abi.encode(safeEngine.params()), abi.encode(_safeEngineParams));
  }
}

contract Unit_SAFEEngine_ModifyParameters is Base {
  function test_ModifyParameters(ISAFEEngine.SAFEEngineParams memory _fuzz) public authorized {
    safeEngine.modifyParameters('safeDebtCeiling', abi.encode(_fuzz.safeDebtCeiling));
    safeEngine.modifyParameters('globalDebtCeiling', abi.encode(_fuzz.globalDebtCeiling));

    ISAFEEngine.SAFEEngineParams memory _params = safeEngine.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_ModifyParameters_PerCollateral(
    bytes32 _cType,
    ISAFEEngine.SAFEEngineCollateralParams memory _fuzz
  ) public authorized {
    _mockCollateralList(_cType);

    safeEngine.modifyParameters(_cType, 'debtCeiling', abi.encode(_fuzz.debtCeiling));
    safeEngine.modifyParameters(_cType, 'debtFloor', abi.encode(_fuzz.debtFloor));

    ISAFEEngine.SAFEEngineCollateralParams memory _cParams = safeEngine.cParams(_cType);

    assertEq(abi.encode(_cParams), abi.encode(_fuzz));
  }

  function test_Revert_ModifyParameters_UnrecognizedParam() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    safeEngine.modifyParameters('unrecognizedParam', abi.encode(0));
  }

  function test_Revert_ModifyParameters_PerCollateral_UnrecognizedParam(bytes32 _cType) public authorized {
    _mockCollateralList(_cType);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    safeEngine.modifyParameters(_cType, 'unrecognizedParam', abi.encode(0));
  }

  function test_Revert_ModifyParameters_PerCollateral_UnrecognizedCType(bytes32 _cType) public authorized {
    vm.expectRevert(IModifiable.UnrecognizedCType.selector);
    safeEngine.modifyParameters(_cType, '', abi.encode(0));
  }
}

contract Unit_SAFEEngine_ModifyCollateralBalance is Base {
  using Math for uint256;

  event TransferCollateral(bytes32 indexed _cType, address indexed _src, address indexed _dst, uint256 _wad);

  function _assumeHappyPath(uint256 _initialCollateral, int256 _wad) internal pure {
    if (_wad == 0) return;
    vm.assume(notUnderOrOverflowAdd(_initialCollateral, _wad));
  }

  function test_Set_TokenCollateral(uint256 _intialCollateral, bytes32 _cType, int256 _wad) public authorized {
    _assumeHappyPath(_intialCollateral, _wad);
    _mockTokenCollateral(_cType, account, _intialCollateral);

    safeEngine.modifyCollateralBalance(_cType, account, _wad);

    assertEq(safeEngine.tokenCollateral(_cType, account), _intialCollateral.add(_wad));
  }

  function testFail_Emit_TransferCollateral_Null(uint256 _initialCollateral) public authorized {
    _assumeHappyPath(_initialCollateral, 0);
    _mockTokenCollateral(collateralType, account, _initialCollateral);

    vm.expectEmit();
    emit TransferCollateral(collateralType, address(0), account, 0);

    safeEngine.modifyCollateralBalance(collateralType, account, 0);
  }

  function test_Emit_TransferCollateral_Positive(uint256 _intialCollateral, int256 _wad) public authorized {
    vm.assume(_wad > 0);
    _assumeHappyPath(_intialCollateral, _wad);
    _mockTokenCollateral(collateralType, account, _intialCollateral);

    vm.expectEmit();
    emit TransferCollateral(collateralType, address(0), account, uint256(_wad));

    safeEngine.modifyCollateralBalance(collateralType, account, _wad);
  }

  function test_Emit_TransferCollateral_Negative(uint256 _intialCollateral, int256 _wad) public authorized {
    vm.assume(_wad < 0);
    _assumeHappyPath(_intialCollateral, _wad);
    _mockTokenCollateral(collateralType, account, _intialCollateral);

    vm.expectEmit();
    emit TransferCollateral(collateralType, account, address(0), uint256(-_wad));

    safeEngine.modifyCollateralBalance(collateralType, account, _wad);
  }

  function test_Revert_NotAuthorized(bytes32 _cType, int256 _wad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    safeEngine.modifyCollateralBalance(_cType, account, _wad);
  }
}

contract Unit_SAFEEngine_TransferCollateral is Base {
  event TransferCollateral(bytes32 indexed _cType, address indexed _src, address indexed _dst, uint256 _wad);

  function _assumeHappyPath(uint256 _initialCollateralSrc, uint256 _initialCollateralDst, uint256 _wad) internal pure {
    vm.assume(notUnderflow(_initialCollateralSrc, _wad));
    vm.assume(notOverflowAdd(_initialCollateralDst, _wad));
  }

  function _mockValues(uint256 _initialCollateralSrc, uint256 _initialCollateralDst) internal {
    _mockTokenCollateral(collateralType, src, _initialCollateralSrc);
    _mockTokenCollateral(collateralType, dst, _initialCollateralDst);
  }

  function test_Set_TokenCollateralSrc(
    uint256 _initialCollateralSrc,
    uint256 _initialCollateralDst,
    uint256 _wad
  ) public {
    _assumeHappyPath(_initialCollateralSrc, _initialCollateralDst, _wad);
    _mockValues(_initialCollateralSrc, _initialCollateralDst);

    vm.prank(src);
    safeEngine.transferCollateral(collateralType, src, dst, _wad);

    assertEq(safeEngine.tokenCollateral(collateralType, src), _initialCollateralSrc - _wad);
  }

  function test_Set_TokenCollateralDst(
    uint256 _initialCollateralSrc,
    uint256 _initialCollateralDst,
    uint256 _wad
  ) public {
    _assumeHappyPath(_initialCollateralSrc, _initialCollateralDst, _wad);
    _mockValues(_initialCollateralSrc, _initialCollateralDst);

    vm.prank(src);
    safeEngine.transferCollateral(collateralType, src, dst, _wad);

    assertEq(safeEngine.tokenCollateral(collateralType, dst), _initialCollateralDst + _wad);
  }

  function test_Emit_TransferCollateral(
    uint256 _initialCollateralSrc,
    uint256 _initialCollateralDst,
    uint256 _wad
  ) public {
    _assumeHappyPath(_initialCollateralSrc, _initialCollateralDst, _wad);
    _mockValues(_initialCollateralSrc, _initialCollateralDst);

    vm.expectEmit();
    emit TransferCollateral(collateralType, src, dst, _wad);

    vm.prank(src);
    safeEngine.transferCollateral(collateralType, src, dst, _wad);
  }

  function test_Revert_CannotModifySAFE(bytes32 collateralType, uint256 _wad) public {
    vm.expectRevert(ISAFEEngine.SAFEEng_NotSAFEAllowed.selector);

    vm.prank(dst);
    safeEngine.transferCollateral(collateralType, src, dst, _wad);
  }
}

contract Unit_SAFEEngine_TransferInternalCoins is Base {
  event TransferInternalCoins(address indexed _src, address indexed _dst, uint256 _rad);

  function _assumeHappyPath(uint256 _initialBalanceSrc, uint256 _initialBalanceDst, uint256 _rad) internal pure {
    vm.assume(notUnderflow(_initialBalanceSrc, _rad));
    vm.assume(notOverflowAdd(_initialBalanceDst, _rad));
  }

  function _mockValues(uint256 _initialBalanceSrc, uint256 _initialBalanceDst) internal {
    _mockCoinBalance(src, _initialBalanceSrc);
    _mockCoinBalance(dst, _initialBalanceDst);
  }

  function test_Set_CoinsBalanceSrc(uint256 _initialBalanceSrc, uint256 _initialBalanceDst, uint256 _rad) public {
    _assumeHappyPath(_initialBalanceSrc, _initialBalanceDst, _rad);
    _mockValues(_initialBalanceSrc, _initialBalanceDst);

    vm.prank(src);
    safeEngine.transferInternalCoins(src, dst, _rad);

    assertEq(safeEngine.coinBalance(src), _initialBalanceSrc - _rad);
  }

  function test_Set_CoinsBalanceDst(uint256 _initialBalanceSrc, uint256 _initialBalanceDst, uint256 _rad) public {
    _assumeHappyPath(_initialBalanceSrc, _initialBalanceDst, _rad);
    _mockValues(_initialBalanceSrc, _initialBalanceDst);

    vm.prank(src);
    safeEngine.transferInternalCoins(src, dst, _rad);

    assertEq(safeEngine.coinBalance(dst), _initialBalanceDst + _rad);
  }

  function test_Emit_TransferInternalCoins(uint256 _initialBalanceSrc, uint256 _initialBalanceDst, uint256 _rad) public {
    _assumeHappyPath(_initialBalanceSrc, _initialBalanceDst, _rad);
    _mockValues(_initialBalanceSrc, _initialBalanceDst);

    vm.expectEmit();
    emit TransferInternalCoins(src, dst, _rad);

    vm.prank(src);
    safeEngine.transferInternalCoins(src, dst, _rad);
  }

  function test_Revert_CannotModifySAFE(uint256 _rad) public {
    vm.expectRevert(ISAFEEngine.SAFEEng_NotSAFEAllowed.selector);

    vm.prank(dst);
    safeEngine.transferInternalCoins(src, dst, _rad);
  }
}

contract Unit_SAFEEngine_SettleDebt is Base {
  event SettleDebt(address indexed _account, uint256 _rad);

  function _assumeHappyPath(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) internal pure {
    vm.assume(notOverflowInt256(_rad));
    vm.assume(notUnderflow(_initialDebtBalance, _rad));
    vm.assume(notUnderflow(_initialCoinBalance, _rad));
    vm.assume(notUnderflow(_initialGlobalUnbackedDebt, _rad));
    vm.assume(notUnderflow(_globalDebt, _rad));
  }

  function _mockValues(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt
  ) internal {
    _mockCoinBalance(account, _initialCoinBalance);
    _mockDebtBalance(account, _initialDebtBalance);
    _mockGlobalUnbackedDebt(_initialGlobalUnbackedDebt);
    _mockGlobalDebt(_globalDebt);
  }

  function test_Set_DebtBalance(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    vm.prank(account);
    safeEngine.settleDebt(_rad);

    assertEq(safeEngine.debtBalance(account), _initialDebtBalance - _rad);
  }

  function test_Set_CoinBalance(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    vm.prank(account);
    safeEngine.settleDebt(_rad);

    assertEq(safeEngine.coinBalance(account), _initialCoinBalance - _rad);
  }

  function test_Set_GlobalUnbackedDebt(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    vm.prank(account);
    safeEngine.settleDebt(_rad);

    assertEq(safeEngine.globalUnbackedDebt(), _initialGlobalUnbackedDebt - _rad);
  }

  function test_Set_GlobalDebt(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    vm.prank(account);
    safeEngine.settleDebt(_rad);

    assertEq(safeEngine.globalDebt(), _globalDebt - _rad);
  }

  function test_Emit_SettleDebt(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    vm.expectEmit();
    emit SettleDebt(account, _rad);

    vm.prank(account);
    safeEngine.settleDebt(_rad);
  }
}

contract Unit_SAFEEngine_CreateUnbackedDebt is Base {
  event CreateUnbackedDebt(address indexed _debtDestination, address indexed _coinDestination, uint256 _rad);

  function _mockValues(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt
  ) internal {
    _mockCoinBalance(coinDestination, _initialCoinBalance);
    _mockDebtBalance(debtDestination, _initialDebtBalance);
    _mockGlobalUnbackedDebt(_initialGlobalUnbackedDebt);
    _mockGlobalDebt(_globalDebt);
  }

  function _assumeHappyPath(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) internal pure {
    vm.assume(notOverflowInt256(_rad));
    vm.assume(notOverflowAdd(_initialDebtBalance, _rad));
    vm.assume(notOverflowAdd(_initialCoinBalance, _rad));
    vm.assume(notOverflowAdd(_initialGlobalUnbackedDebt, _rad));
    vm.assume(notOverflowAdd(_globalDebt, _rad));
  }

  function test_Set_DebtBalance(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public authorized {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    safeEngine.createUnbackedDebt(debtDestination, coinDestination, _rad);

    assertEq(safeEngine.debtBalance(debtDestination), _initialDebtBalance + _rad);
  }

  function test_Set_CoinBalance(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public authorized {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    safeEngine.createUnbackedDebt(debtDestination, coinDestination, _rad);

    assertEq(safeEngine.coinBalance(coinDestination), _initialCoinBalance + _rad);
  }

  function test_Set_GlobalUnbackedDebt(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public authorized {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    safeEngine.createUnbackedDebt(debtDestination, coinDestination, _rad);

    assertEq(safeEngine.globalUnbackedDebt(), _initialGlobalUnbackedDebt + _rad);
  }

  function test_Set_GlobalDebt(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public authorized {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    safeEngine.createUnbackedDebt(debtDestination, coinDestination, _rad);

    assertEq(safeEngine.globalDebt(), _globalDebt + _rad);
  }

  function test_Emit_CreateUnbackedDebt(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) public authorized {
    _assumeHappyPath(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt, _rad);
    _mockValues(_initialDebtBalance, _initialCoinBalance, _initialGlobalUnbackedDebt, _globalDebt);

    vm.expectEmit();
    emit CreateUnbackedDebt(debtDestination, coinDestination, _rad);

    safeEngine.createUnbackedDebt(debtDestination, coinDestination, _rad);
  }
}

contract Unit_SAFEEngine_UpdateAccumulatedRate is Base {
  using Math for uint256;

  struct UpdateAccumulatedRateScenario {
    int256 rateMultiplier;
    uint256 collateralTypeDebtAmount;
    uint256 collateralTypeAccumulatedRate;
    uint256 surplusDstCoinBalance;
    uint256 initialGlobalDebt;
  }

  event UpdateAccumulatedRate(bytes32 indexed _cType, address _surplusDst, int256 _rateMultiplier);

  function _assumeHappyPath(UpdateAccumulatedRateScenario memory _scenario) internal pure {
    vm.assume(notUnderOrOverflowMul(_scenario.collateralTypeDebtAmount, _scenario.rateMultiplier));
    int256 _deltaSurplus = int256(_scenario.collateralTypeDebtAmount) * _scenario.rateMultiplier;
    vm.assume(notUnderOrOverflowAdd(_scenario.collateralTypeAccumulatedRate, _scenario.rateMultiplier));
    vm.assume(notUnderOrOverflowAdd(_scenario.initialGlobalDebt, _deltaSurplus));
    vm.assume(notUnderOrOverflowAdd(_scenario.surplusDstCoinBalance, _deltaSurplus));
  }

  function _mockValues(UpdateAccumulatedRateScenario memory _scenario) internal {
    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: _scenario.collateralTypeDebtAmount,
        lockedAmount: 0,
        accumulatedRate: _scenario.collateralTypeAccumulatedRate,
        safetyPrice: 0,
        liquidationPrice: 0
      })
    );
    _mockCoinBalance(surplusDst, _scenario.surplusDstCoinBalance);
    _mockGlobalDebt(_scenario.initialGlobalDebt);
  }

  function test_Set_AccumulatedRate(UpdateAccumulatedRateScenario memory _scenario) public authorized {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _scenario.rateMultiplier);

    uint256 _newAccumulatedRate = safeEngine.cData(collateralType).accumulatedRate;
    assertEq(_newAccumulatedRate, _scenario.collateralTypeAccumulatedRate.add(_scenario.rateMultiplier));
  }

  function test_Set_CoinBalance(UpdateAccumulatedRateScenario memory _scenario) public authorized {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _scenario.rateMultiplier);

    assertEq(
      safeEngine.coinBalance(surplusDst),
      _scenario.surplusDstCoinBalance.add(_scenario.collateralTypeDebtAmount.mul(_scenario.rateMultiplier))
    );
  }

  function test_Set_GlobalDebt(UpdateAccumulatedRateScenario memory _scenario) public authorized {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _scenario.rateMultiplier);

    assertEq(
      safeEngine.globalDebt(),
      _scenario.initialGlobalDebt.add(_scenario.collateralTypeDebtAmount.mul(_scenario.rateMultiplier))
    );
  }

  function test_Emit_UpdateAccumulatedRate(UpdateAccumulatedRateScenario memory _scenario) public authorized {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectEmit();
    emit UpdateAccumulatedRate(collateralType, surplusDst, _scenario.rateMultiplier);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _scenario.rateMultiplier);
  }

  function test_Revert_NotAuthorized(int256 _rateMultiplier) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);
  }

  function test_Revert_ContractIsDisabled(int256 _rateMultiplier) public authorized {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);
  }
}

contract Unit_SAFEEngine_ModifySafeCollateralization is Base {
  using Math for uint256;

  event ModifySAFECollateralization(
    bytes32 indexed _cType,
    address indexed _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  );

  struct ModifySAFECollateralizationScenario {
    ISAFEEngine.SAFE safeData;
    ISAFEEngine.SAFEEngineCollateralData cData;
    uint256 coinBalance;
    uint256 collateralBalance;
    int256 deltaCollateral;
    int256 deltaDebt;
    uint256 globalDebt;
  }

  function _assumeHappyPath(ModifySAFECollateralizationScenario memory _scenario) internal pure {
    // global
    vm.assume(_scenario.cData.accumulatedRate != 0);

    // modify collateral balance
    vm.assume(notUnderOrOverflowSub(_scenario.collateralBalance, _scenario.deltaCollateral));

    // modify safe collateralization
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.lockedCollateral, _scenario.deltaCollateral));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.generatedDebt, _scenario.deltaDebt));
    uint256 _newLockedCollateral = _scenario.safeData.lockedCollateral.add(_scenario.deltaCollateral);
    uint256 _newSafeDebt = _scenario.safeData.generatedDebt.add(_scenario.deltaDebt);

    // modify collateral debt
    vm.assume(notUnderOrOverflowAdd(_scenario.cData.debtAmount, _scenario.deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_scenario.cData.lockedAmount, _scenario.deltaCollateral));
    uint256 _newCollateralDebt = _scenario.cData.debtAmount.add(_scenario.deltaDebt);

    // modify internal coins (calculates rate adjusted debt)
    vm.assume(notUnderOrOverflowMul(_scenario.cData.accumulatedRate, _scenario.deltaDebt));
    int256 _deltaAdjustedDebt = _scenario.cData.accumulatedRate.mul(_scenario.deltaDebt);
    vm.assume(notUnderOrOverflowAdd(_scenario.coinBalance, _deltaAdjustedDebt));

    // modify globalDebt
    vm.assume(notUnderOrOverflowAdd(_scenario.globalDebt, _deltaAdjustedDebt));

    // --- Safety checks ---

    vm.assume(notOverflowMul(_scenario.cData.accumulatedRate, _newSafeDebt));
    uint256 _totalDebtIssued = _scenario.cData.accumulatedRate * _newSafeDebt;

    // ceilings
    vm.assume(notOverflowMul(_scenario.cData.accumulatedRate, _newCollateralDebt));

    // safety
    vm.assume(notOverflowMul(_scenario.cData.accumulatedRate, _newSafeDebt));
    vm.assume(notOverflowMul(_newLockedCollateral, _scenario.cData.safetyPrice));
    if (_scenario.deltaDebt > 0 || _scenario.deltaCollateral < 0) {
      vm.assume(_totalDebtIssued <= _newLockedCollateral * _scenario.cData.safetyPrice);
    }
  }

  function _mockValues(ModifySAFECollateralizationScenario memory _scenario) internal {
    // NOTE: it mocks the system in the most permissive way possible (floors: 0 and ceilings: max)
    _mockParams(
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: type(uint256).max})
    );
    _mockSafeData(collateralType, safe, _scenario.safeData);
    _mockCollateralType(collateralType, _scenario.cData);
    _mockCollateralParams(
      collateralType, ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: type(uint256).max, debtFloor: 0})
    );
    _mockCoinBalance(debtDestination, _scenario.coinBalance);
    _mockTokenCollateral(collateralType, src, _scenario.collateralBalance);
    _mockGlobalDebt(_scenario.globalDebt);
    _mockCanModifySafe(src, safe, true);
    _mockCanModifySafe(debtDestination, safe, true);
  }

  modifier happyPath(ModifySAFECollateralizationScenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    _;
  }

  function test_Set_SafeDataLockedCollateral(ModifySAFECollateralizationScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newLockedCollateral = safeEngine.safes(collateralType, safe).lockedCollateral;
    assertEq(_newLockedCollateral, _scenario.safeData.lockedCollateral.add(_scenario.deltaCollateral));
  }

  function test_Set_SafeDataGeneratedDebt(ModifySAFECollateralizationScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newGeneratedDebt = safeEngine.safes(collateralType, safe).generatedDebt;
    assertEq(_newGeneratedDebt, _scenario.safeData.generatedDebt.add(_scenario.deltaDebt));
  }

  function test_Set_CollateralTypeDataDebtAmount(ModifySAFECollateralizationScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newDebtAmount = safeEngine.cData(collateralType).debtAmount;

    assertEq(_newDebtAmount, _scenario.cData.debtAmount.add(_scenario.deltaDebt));
  }

  function test_Set_CollateralTypeDataLockedAmount(ModifySAFECollateralizationScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newLockedAmount = safeEngine.cData(collateralType).lockedAmount;

    assertEq(_newLockedAmount, _scenario.cData.lockedAmount.add(_scenario.deltaCollateral));
  }

  function test_Set_GlobalDebt(ModifySAFECollateralizationScenario memory _scenario) public happyPath(_scenario) {
    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    assertEq(
      safeEngine.globalDebt(), _scenario.globalDebt.add(_scenario.cData.accumulatedRate.mul(_scenario.deltaDebt))
    );
  }

  function test_Set_TokenCollateral(ModifySAFECollateralizationScenario memory _scenario) public happyPath(_scenario) {
    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    assertEq(
      safeEngine.tokenCollateral(collateralType, src), _scenario.collateralBalance.sub(_scenario.deltaCollateral)
    );
  }

  function test_Set_CoinBalance(ModifySAFECollateralizationScenario memory _scenario) public happyPath(_scenario) {
    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    assertEq(
      safeEngine.coinBalance(debtDestination),
      _scenario.coinBalance.add(_scenario.cData.accumulatedRate.mul(_scenario.deltaDebt))
    );
  }

  function test_Emit_ModifySAFECollateralization(ModifySAFECollateralizationScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectEmit();
    emit ModifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_ContractIsDisabled() public {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, 0);
  }

  function test_Revert_CollateralNotInitialized() public {
    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: 0,
        lockedAmount: 0,
        accumulatedRate: 0,
        safetyPrice: 0,
        liquidationPrice: 0
      })
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_CollateralTypeNotInitialized.selector);

    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, 0);
  }

  function test_Revert_CeilingExceeded_Global(
    ModifySAFECollateralizationScenario memory _scenario,
    uint256 _globalDebtCeiling
  ) public {
    _assumeHappyPath(_scenario);
    int256 _deltaAdjustedDebt = _scenario.cData.accumulatedRate.mul(_scenario.deltaDebt);

    vm.assume(_scenario.deltaDebt > 0);
    _mockValues(_scenario);
    _globalDebtCeiling = _scenario.globalDebt.add(_deltaAdjustedDebt) - 1;
    _mockParams(
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: _globalDebtCeiling})
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_GlobalDebtCeilingHit.selector);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_CeilingExceeded_Collateral(
    ModifySAFECollateralizationScenario memory _scenario,
    uint256 _debtCeiling
  ) public {
    _assumeHappyPath(_scenario);
    vm.assume(_scenario.deltaDebt > 0);
    _debtCeiling = _scenario.cData.accumulatedRate * _scenario.cData.debtAmount.add(_scenario.deltaDebt) - 1;
    _mockValues(_scenario);
    _mockCollateralParams(
      collateralType, ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: _debtCeiling, debtFloor: 0})
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_CollateralDebtCeilingHit.selector);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_NotSafe(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    uint256 _newSafeDebt = _scenario.safeData.generatedDebt.add(_scenario.deltaDebt);
    uint256 _totalDebtIssued = _scenario.cData.accumulatedRate * _newSafeDebt;
    vm.assume(_scenario.deltaDebt > 0 || _scenario.deltaCollateral < 0);
    uint256 _newSafeCollateral = _scenario.safeData.lockedCollateral.add(_scenario.deltaCollateral);
    vm.assume(_newSafeCollateral > 0 && _scenario.cData.safetyPrice > 0);
    vm.assume(_totalDebtIssued > 0);
    vm.assume(_totalDebtIssued / _newSafeCollateral > 0);
    _scenario.cData.safetyPrice = _totalDebtIssued / _newSafeCollateral - 1;
    _mockValues(_scenario);

    vm.expectRevert(ISAFEEngine.SAFEEng_SAFENotSafe.selector);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_NotAllowedToModifySafe(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    _mockCanModifySafe(debtDestination, address(this), true);
    _mockCanModifySafe(safe, address(this), false);
    vm.assume(_scenario.deltaDebt > 0 || _scenario.deltaCollateral < 0);

    vm.expectRevert(ISAFEEngine.SAFEEng_NotSAFEAllowed.selector);

    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_NotAllowedCollateralSrc(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    _mockCanModifySafe(src, safe, false);
    vm.assume(_scenario.deltaCollateral > 0);

    vm.expectRevert(ISAFEEngine.SAFEEng_NotCollateralSrcAllowed.selector);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_NotAllowedDebtDst(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    _mockCanModifySafe(debtDestination, safe, false);
    vm.assume(_scenario.deltaDebt < 0);

    vm.expectRevert(ISAFEEngine.SAFEEng_NotDebtDstAllowed.selector);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_NoDebt(ModifySAFECollateralizationScenario memory _scenario, uint256 _debtFloor) public {
    _assumeHappyPath(_scenario);
    uint256 _newSafeDebt = _scenario.safeData.generatedDebt.add(_scenario.deltaDebt);
    uint256 _totalDebtIssued = _scenario.cData.accumulatedRate * _newSafeDebt;
    vm.assume(_newSafeDebt > 0);
    vm.assume(_totalDebtIssued < type(uint256).max);
    _debtFloor = _totalDebtIssued + 1;
    _mockValues(_scenario);
    _mockCollateralParams(
      collateralType, ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: type(uint256).max, debtFloor: _debtFloor})
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_DustySAFE.selector);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_AboveDebtLimit(
    ModifySAFECollateralizationScenario memory _scenario,
    uint256 _safeDebtCeiling
  ) public {
    _assumeHappyPath(_scenario);

    vm.assume(_scenario.deltaDebt > 0);
    uint256 _newSafeDebt = _scenario.safeData.generatedDebt.add(_scenario.deltaDebt);
    _safeDebtCeiling = _newSafeDebt - 1;
    _mockValues(_scenario);
    _mockParams(ISAFEEngine.SAFEEngineParams({safeDebtCeiling: _safeDebtCeiling, globalDebtCeiling: type(uint256).max}));

    vm.expectRevert(ISAFEEngine.SAFEEng_SAFEDebtCeilingHit.selector);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }
}

contract Unit_SAFEEngine_TransferSafeCollateralAndDebt is Base {
  using Math for uint256;
  using stdStorage for StdStorage;

  event TransferSAFECollateralAndDebt(
    bytes32 indexed _cType, address indexed _src, address indexed _dst, int256 _deltaCollateral, int256 _deltaDebt
  );

  struct TransferSAFECollateralAndDebtScenario {
    // state
    ISAFEEngine.SAFE safeSrc;
    ISAFEEngine.SAFE safeDst;
    // args
    int256 deltaCollateral;
    int256 deltaDebt;
  }

  function _assumeHappyPath(TransferSAFECollateralAndDebtScenario memory _scenario) internal pure {
    // needs to be negated
    if (_scenario.deltaCollateral < 0) vm.assume(_scenario.deltaCollateral != type(int256).min);
    if (_scenario.deltaDebt < 0) vm.assume(_scenario.deltaDebt != type(int256).min);

    vm.assume(notUnderOrOverflowSub(_scenario.safeSrc.lockedCollateral, _scenario.deltaCollateral));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeDst.lockedCollateral, _scenario.deltaCollateral));

    vm.assume(notUnderOrOverflowSub(_scenario.safeSrc.generatedDebt, _scenario.deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeDst.generatedDebt, _scenario.deltaDebt));
  }

  function _mockValues(TransferSAFECollateralAndDebtScenario memory _scenario) internal {
    _mockSafeData(collateralType, src, _scenario.safeSrc);
    _mockSafeData(collateralType, dst, _scenario.safeDst);

    uint256 _maxCollateral = Math.max(
      _scenario.safeSrc.lockedCollateral.sub(_scenario.deltaCollateral),
      _scenario.safeDst.lockedCollateral.add(_scenario.deltaCollateral)
    );
    vm.assume(_maxCollateral != type(uint256).max);
    uint256 _maxSafetyPrice = type(uint256).max / Math.max(_maxCollateral, 1);

    // NOTE: it mocks the system in the most permissive way possible (accumulatedRate: 0 and safetyPrice: max)
    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: 0,
        lockedAmount: 0,
        accumulatedRate: 0,
        safetyPrice: _maxSafetyPrice,
        liquidationPrice: 0
      })
    );

    // NOTE: it mocks the system in the most permissive way possible (floors: 0 and ceilings: max)
    _mockCollateralParams(
      collateralType, ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: type(uint256).max, debtFloor: 0})
    );

    _mockCanModifySafe(src, account, true);
    _mockCanModifySafe(dst, account, true);
  }

  modifier happyPath(TransferSAFECollateralAndDebtScenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    _;
  }

  function test_Set_SrcSafeLockedCollateral(TransferSAFECollateralAndDebtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);

    uint256 _srcLockedCollateral = safeEngine.safes(collateralType, src).lockedCollateral;
    assertEq(_srcLockedCollateral, _scenario.safeSrc.lockedCollateral.sub(_scenario.deltaCollateral));
  }

  function test_Set_SrcSafeGeneratedDebt(TransferSAFECollateralAndDebtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);

    uint256 _srcGeneratedDebt = safeEngine.safes(collateralType, src).generatedDebt;
    assertEq(_srcGeneratedDebt, _scenario.safeSrc.generatedDebt.sub(_scenario.deltaDebt));
  }

  function test_Set_DstSafeLockedCollateral(TransferSAFECollateralAndDebtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);

    uint256 _dstLockedCollateral = safeEngine.safes(collateralType, dst).lockedCollateral;
    assertEq(_dstLockedCollateral, _scenario.safeDst.lockedCollateral.add(_scenario.deltaCollateral));
  }

  function test_Set_DstSafeGeneratedDebt(TransferSAFECollateralAndDebtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);

    uint256 _dstGeneratedDebt = safeEngine.safes(collateralType, dst).generatedDebt;
    assertEq(_dstGeneratedDebt, _scenario.safeDst.generatedDebt.add(_scenario.deltaDebt));
  }

  function test_Emit_TransferSAFECollateralAndDebt(TransferSAFECollateralAndDebtScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectEmit();
    emit TransferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);
  }

  function test_Revert_CannotModifySafe(
    TransferSAFECollateralAndDebtScenario memory _scenario,
    bool _canModifySrcSafe,
    bool _canModifyDstSafe
  ) public {
    vm.assume(!_canModifySrcSafe || !_canModifyDstSafe);

    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    _mockCanModifySafe(src, account, _canModifySrcSafe);
    _mockCanModifySafe(dst, account, _canModifyDstSafe);

    vm.expectRevert(ISAFEEngine.SAFEEng_NotSAFEAllowed.selector);
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);
  }

  function test_Revert_NotSafeSrc(
    TransferSAFECollateralAndDebtScenario memory _scenario,
    uint256 _accumulatedRate,
    uint256 _safetyPrice
  ) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    uint256 _srcDebt = _scenario.safeSrc.generatedDebt.sub(_scenario.deltaDebt);
    uint256 _dstDebt = _scenario.safeDst.generatedDebt.add(_scenario.deltaDebt);

    _accumulatedRate = bound(_accumulatedRate, 1, type(uint256).max / Math.max((Math.max(_srcDebt, _dstDebt)), 1));

    uint256 _srcCollateral = _scenario.safeSrc.lockedCollateral.sub(_scenario.deltaCollateral);
    uint256 _dstCollateral = _scenario.safeDst.lockedCollateral.add(_scenario.deltaCollateral);

    _safetyPrice = bound(_safetyPrice, 0, type(uint256).max / Math.max((Math.max(_srcCollateral, _dstCollateral)), 1));

    // NOTE: source has to be safe to fail on destination
    vm.assume(_srcDebt * _accumulatedRate > _safetyPrice * _srcCollateral);

    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: 0,
        lockedAmount: 0,
        accumulatedRate: _accumulatedRate,
        safetyPrice: _safetyPrice,
        liquidationPrice: 0
      })
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_SAFENotSafe.selector);
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);
  }

  function test_Revert_NotSafeDst(
    TransferSAFECollateralAndDebtScenario memory _scenario,
    uint256 _safetyPrice,
    uint256 _accumulatedRate
  ) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.assume(_accumulatedRate > 0);

    uint256 _srcDebt = _scenario.safeSrc.generatedDebt.sub(_scenario.deltaDebt);
    uint256 _dstDebt = _scenario.safeDst.generatedDebt.add(_scenario.deltaDebt);

    _accumulatedRate = bound(_accumulatedRate, 1, type(uint256).max / Math.max((Math.max(_srcDebt, _dstDebt)), 1));

    uint256 _srcCollateral = _scenario.safeSrc.lockedCollateral.sub(_scenario.deltaCollateral);
    uint256 _dstCollateral = _scenario.safeDst.lockedCollateral.add(_scenario.deltaCollateral);

    _safetyPrice = bound(_safetyPrice, 0, type(uint256).max / Math.max((Math.max(_srcCollateral, _dstCollateral)), 1));

    // NOTE: source has to be safe to fail on destination
    vm.assume(_srcDebt * _accumulatedRate <= _safetyPrice * _srcCollateral);
    vm.assume(_dstDebt * _accumulatedRate > _safetyPrice * _dstCollateral);

    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: 0,
        lockedAmount: 0,
        accumulatedRate: _accumulatedRate,
        safetyPrice: _safetyPrice,
        liquidationPrice: 0
      })
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_SAFENotSafe.selector);
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);
  }

  function test_Revert_DebtCeilingHit(
    TransferSAFECollateralAndDebtScenario memory _scenario,
    uint256 _safeDebtCeiling
  ) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    uint256 _srcDebt = _scenario.safeSrc.generatedDebt.sub(_scenario.deltaDebt);
    uint256 _dstDebt = _scenario.safeDst.generatedDebt.add(_scenario.deltaDebt);

    _mockSafeDebtCeiling(_safeDebtCeiling);
    vm.assume(_srcDebt > _safeDebtCeiling || _dstDebt > _safeDebtCeiling);

    vm.expectRevert(ISAFEEngine.SAFEEng_SAFEDebtCeilingHit.selector);

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);
  }

  function test_Revert_DustSrc(
    TransferSAFECollateralAndDebtScenario memory _scenario,
    uint256 _safetyPrice,
    uint256 _accumulatedRate,
    uint256 _debtFloor
  ) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    uint256 _srcDebt = _scenario.safeSrc.generatedDebt.sub(_scenario.deltaDebt);
    uint256 _dstDebt = _scenario.safeDst.generatedDebt.add(_scenario.deltaDebt);
    vm.assume(_srcDebt != 0);

    _accumulatedRate = bound(_accumulatedRate, 1, type(uint256).max / Math.max((Math.max(_srcDebt, _dstDebt)), 1));

    uint256 _srcCollateral = _scenario.safeSrc.lockedCollateral.sub(_scenario.deltaCollateral);
    uint256 _dstCollateral = _scenario.safeDst.lockedCollateral.add(_scenario.deltaCollateral);

    // NOTE: safety price has to be greater than 0, else safes debt needs to be 0 (non-dusty)
    _safetyPrice = bound(_safetyPrice, 1, type(uint256).max / Math.max((Math.max(_srcCollateral, _dstCollateral)), 1));

    // NOTE: safes have to be safe to be dusty
    vm.assume(_srcDebt * _accumulatedRate <= _safetyPrice * _srcCollateral);
    vm.assume(_dstDebt * _accumulatedRate <= _safetyPrice * _dstCollateral);

    vm.assume(_srcDebt * _accumulatedRate < _debtFloor);

    _mockDebtFloor(collateralType, _debtFloor);
    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: 0,
        lockedAmount: 0,
        accumulatedRate: _accumulatedRate,
        safetyPrice: _safetyPrice,
        liquidationPrice: 0
      })
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_DustySAFE.selector);

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);
  }

  function test_Revert_DustDst(
    TransferSAFECollateralAndDebtScenario memory _scenario,
    uint256 _safetyPrice,
    uint256 _accumulatedRate,
    uint256 _debtFloor
  ) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    uint256 _srcDebt = _scenario.safeSrc.generatedDebt.sub(_scenario.deltaDebt);
    uint256 _dstDebt = _scenario.safeDst.generatedDebt.add(_scenario.deltaDebt);
    vm.assume(_dstDebt != 0);

    _accumulatedRate = bound(_accumulatedRate, 1, type(uint256).max / Math.max((Math.max(_srcDebt, _dstDebt)), 1));

    uint256 _srcCollateral = _scenario.safeSrc.lockedCollateral.sub(_scenario.deltaCollateral);
    uint256 _dstCollateral = _scenario.safeDst.lockedCollateral.add(_scenario.deltaCollateral);

    _safetyPrice = bound(_safetyPrice, 1, type(uint256).max / Math.max((Math.max(_srcCollateral, _dstCollateral)), 1));

    // NOTE: both safes have to be safe, and src safe has to be empty or non-dusty
    if (_srcDebt > 0) {
      vm.assume(_srcDebt > _dstDebt);
      vm.assume(_srcDebt * _accumulatedRate <= _safetyPrice * _srcCollateral);
      vm.assume(_srcDebt * _accumulatedRate >= _debtFloor);
    }

    vm.assume(_dstDebt * _accumulatedRate <= _safetyPrice * _dstCollateral);
    vm.assume(_dstDebt * _accumulatedRate < _debtFloor);

    _mockDebtFloor(collateralType, _debtFloor);
    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: 0,
        lockedAmount: 0,
        accumulatedRate: _accumulatedRate,
        safetyPrice: _safetyPrice,
        liquidationPrice: 0
      })
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_DustySAFE.selector);

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _scenario.deltaCollateral, _scenario.deltaDebt);
  }
}

contract Unit_SAFEEngine_ConfiscateSAFECollateralAndDebt is Base {
  using Math for uint256;

  event ConfiscateSAFECollateralAndDebt(
    bytes32 indexed _cType,
    address indexed _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  );

  struct ConfiscateSAFEScenario {
    ISAFEEngine.SAFE safeData;
    // cData
    uint256 debtAmount;
    uint256 lockedAmount;
    uint256 accumulatedRate;
    // state vars
    uint256 collateralSourceBalance;
    uint256 debtDestinationDebt;
    uint256 globalUnbackedDebt;
    // method args
    int256 deltaCollateral;
    int256 deltaDebt;
  }

  function _assumeHappyPath(ConfiscateSAFEScenario memory _scenario) internal pure {
    vm.assume(notUnderOrOverflowMul(_scenario.accumulatedRate, _scenario.deltaDebt));

    vm.assume(notUnderOrOverflowSub(_scenario.collateralSourceBalance, _scenario.deltaCollateral));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.lockedCollateral, _scenario.deltaCollateral));
    vm.assume(notUnderOrOverflowAdd(_scenario.safeData.generatedDebt, _scenario.deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_scenario.debtAmount, _scenario.deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_scenario.lockedAmount, _scenario.deltaCollateral));

    int256 _deltaTotalIssuedDebt = _scenario.accumulatedRate.mul(_scenario.deltaDebt);
    vm.assume(notUnderOrOverflowSub(_scenario.debtDestinationDebt, _deltaTotalIssuedDebt));
    vm.assume(notUnderOrOverflowSub(_scenario.globalUnbackedDebt, _deltaTotalIssuedDebt));
  }

  function _mockValues(ConfiscateSAFEScenario memory _scenario) internal {
    _mockSafeData(collateralType, safe, _scenario.safeData);

    _mockCollateralType(
      collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: _scenario.debtAmount,
        lockedAmount: _scenario.lockedAmount,
        accumulatedRate: _scenario.accumulatedRate,
        safetyPrice: 1,
        liquidationPrice: 0
      })
    );

    _mockTokenCollateral(collateralType, collateralSource, _scenario.collateralSourceBalance);
    _mockDebtBalance(debtDestination, _scenario.debtDestinationDebt);
    _mockGlobalUnbackedDebt(_scenario.globalUnbackedDebt);
  }

  modifier happyPath(ConfiscateSAFEScenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    vm.startPrank(deployer);
    _;
  }

  function test_Set_SafeLockedCollateral(ConfiscateSAFEScenario memory _scenario) public happyPath(_scenario) {
    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _lockedCollateral = safeEngine.safes(collateralType, safe).lockedCollateral;
    assertEq(_lockedCollateral, _scenario.safeData.lockedCollateral.add(_scenario.deltaCollateral));
  }

  function test_Set_GeneratedDebt(ConfiscateSAFEScenario memory _scenario) public happyPath(_scenario) {
    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _generatedDebt = safeEngine.safes(collateralType, safe).generatedDebt;
    assertEq(_generatedDebt, _scenario.safeData.generatedDebt.add(_scenario.deltaDebt));
  }

  function test_Set_DebtAmount(ConfiscateSAFEScenario memory _scenario) public happyPath(_scenario) {
    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _debtAmount = safeEngine.cData(collateralType).debtAmount;
    assertEq(_debtAmount, _scenario.debtAmount.add(_scenario.deltaDebt));
  }

  function test_Set_LockedAmount(ConfiscateSAFEScenario memory _scenario) public happyPath(_scenario) {
    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _lockedAmount = safeEngine.cData(collateralType).lockedAmount;
    assertEq(_lockedAmount, _scenario.lockedAmount.add(_scenario.deltaCollateral));
  }

  function test_Set_TokenCollateral(ConfiscateSAFEScenario memory _scenario) public happyPath(_scenario) {
    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newTokenCollateral = safeEngine.tokenCollateral(collateralType, collateralSource);
    assertEq(_newTokenCollateral, _scenario.collateralSourceBalance.sub(_scenario.deltaCollateral));
  }

  function test_Set_DebtBalance(ConfiscateSAFEScenario memory _scenario) public happyPath(_scenario) {
    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newDebtBalance = safeEngine.debtBalance(debtDestination);
    assertEq(_newDebtBalance, _scenario.debtDestinationDebt.sub(_scenario.accumulatedRate.mul(_scenario.deltaDebt)));
  }

  function test_Set_GlobalUnbackedDebt(ConfiscateSAFEScenario memory _scenario) public happyPath(_scenario) {
    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    assertEq(
      safeEngine.globalUnbackedDebt(),
      _scenario.globalUnbackedDebt.sub(_scenario.accumulatedRate.mul(_scenario.deltaDebt))
    );
  }

  function test_Emit_ConfiscateSAFECollateralAndDebt(ConfiscateSAFEScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    vm.expectEmit();
    emit ConfiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }
}

contract Unit_SAFEEngine_ApproveSAFEModification is Base {
  event ApproveSAFEModification(address _sender, address _account);

  function test_Set_SafeRights(address _sender, address _account) public {
    vm.prank(_sender);

    safeEngine.approveSAFEModification(_account);

    assertEq(safeEngine.safeRights(_sender, _account), true);
  }

  function test_Emit_ApproveSAFEModification(address _sender, address _account) public {
    vm.prank(_sender);

    vm.expectEmit();
    emit ApproveSAFEModification(_sender, _account);

    safeEngine.approveSAFEModification(_account);
  }
}

contract Unit_SAFEEngine_DenySAFEModification is Base {
  event DenySAFEModification(address _sender, address _account);

  function test_Set_SafeRights(address _sender, address _account) public {
    _mockCanModifySafe(_sender, _account, true);

    vm.prank(_sender);
    safeEngine.denySAFEModification(_account);

    assertEq(safeEngine.safeRights(_sender, _account), false);
  }

  function test_Emit_DenySAFEModification(address _sender, address _account) public {
    _mockCanModifySafe(_sender, _account, true);

    vm.expectEmit();
    emit DenySAFEModification(_sender, _account);

    vm.prank(_sender);
    safeEngine.denySAFEModification(_account);
  }
}

contract Unit_SAFEEngine_CanModifySafe is Base {
  function test_Return_SameAccountCanModify(address _account) public {
    // Even though we deny it, because it is the same account it should be able to modify
    _mockCanModifySafe(_account, _account, false);

    assertEq(safeEngine.canModifySAFE(_account, _account), true);
  }

  function test_Return_CanModify(address _sender, address _account) public {
    _mockCanModifySafe(_sender, _account, true);

    assertEq(safeEngine.canModifySAFE(_account, _account), true);
  }

  function test_Return_CannotModify(address _sender, address _account) public {
    vm.assume(_sender != _account);
    _mockCanModifySafe(_sender, _account, false);

    assertEq(safeEngine.canModifySAFE(_account, _account), true);
  }
}

contract Unit_SAFEEngine_InitializeCollateralType is Base {
  event InitializeCollateralType(bytes32 _cType);

  function test_Set_AccummulatedRate(
    bytes32 _cType,
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCParams
  ) public authorized {
    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams));

    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    assertEq(_accumulatedRate, RAY);
  }

  function test_Set_CParams(
    bytes32 _cType,
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCParams
  ) public authorized {
    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams));

    assertEq(abi.encode(safeEngine.cParams(_cType)), abi.encode(_safeEngineCParams));
  }

  function test_Emit_InitializeCollateralType(
    bytes32 _cType,
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCParams
  ) public authorized {
    vm.expectEmit();
    emit InitializeCollateralType(_cType);

    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams));
  }

  function test_Revert_NotAuthorized(
    bytes32 _cType,
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCParams
  ) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams));
  }

  function test_Revert_CollateralTypeAlreadyExists(
    bytes32 _cType,
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCParams
  ) public authorized {
    _mockCollateralList(_cType);

    vm.expectRevert(IModifiablePerCollateral.CollateralTypeAlreadyInitialized.selector);

    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams));
  }

  function test_Revert_ContractIsDisabled(
    bytes32 _cType,
    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCParams
  ) public authorized {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    safeEngine.initializeCollateralType(_cType, abi.encode(_safeEngineCParams));
  }
}
