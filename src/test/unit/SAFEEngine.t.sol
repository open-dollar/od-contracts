// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

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
  bytes32 collateralType = bytes32('collateralTest');

  ISAFEEngine safeEngine;

  function setUp() public virtual {
    vm.prank(deployer);

    safeEngine = new SAFEEngine(safeEngineParams);
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
    vm.stopPrank();
  }

  function _mockTokenCollateral(bytes32 _collateralType, address _account, uint256 _wad) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.tokenCollateral.selector).with_key(_collateralType).with_key(
      _account
    ).checked_write(_wad);
  }

  function _mockCoinBalance(address _account, uint256 _rad) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.coinBalance.selector).with_key(_account).checked_write(_rad);
  }

  // TODO: rm
  function _mockSafeData(
    bytes32 _collateralType,
    address _safe,
    uint256 _lockedCollateral,
    uint256 _generatedDebt
  ) internal {
    _mockSafeData(
      _collateralType, _safe, ISAFEEngine.SAFE({lockedCollateral: _lockedCollateral, generatedDebt: _generatedDebt})
    );
  }

  function _mockSafeData(bytes32 _collateralType, address _safe, ISAFEEngine.SAFE memory _safeData) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safes.selector).with_key(_collateralType).with_key(_safe).depth(
      0
    ).checked_write(_safeData.lockedCollateral);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safes.selector).with_key(_collateralType).with_key(_safe).depth(
      1
    ).checked_write(_safeData.generatedDebt);
  }

  // TODO: rm
  function _mockCollateralType(
    bytes32 _collateralType,
    uint256 _debtAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _debtCeiling,
    uint256 _debtFloor,
    uint256 _liquidationPrice
  ) internal {
    _mockCollateralType(
      _collateralType,
      ISAFEEngine.SAFEEngineCollateralData({
        debtAmount: _debtAmount,
        accumulatedRate: _accumulatedRate,
        safetyPrice: _safetyPrice,
        liquidationPrice: _liquidationPrice
      })
    );
    _mockCollateralParams(
      _collateralType, ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: _debtCeiling, debtFloor: _debtFloor})
    );
  }

  function _mockCollateralType(bytes32 _cType, ISAFEEngine.SAFEEngineCollateralData memory _cData) internal {
    // cData
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(0).checked_write(
      _cData.debtAmount
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(1).checked_write(
      _cData.accumulatedRate
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(2).checked_write(
      _cData.safetyPrice
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cData.selector).with_key(_cType).depth(3).checked_write(
      _cData.liquidationPrice
    );
  }

  function _mockCollateralParams(bytes32 _cType, ISAFEEngine.SAFEEngineCollateralParams memory _cParams) internal {
    // cParams
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cParams.selector).with_key(_cType).depth(0).checked_write(
      _cParams.debtCeiling
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cParams.selector).with_key(_cType).depth(1).checked_write(
      _cParams.debtFloor
    );
  }

  function _mockParams(uint256 _safeDebtCeiling, uint256 _globalDebtCeiling) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.params.selector).depth(0).checked_write(_safeDebtCeiling);
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

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(safeEngine)).sig(IDisableable.contractEnabled.selector).checked_write(_contractEnabled);
  }

  function _mockCanModifySafe(address _safe, address _account, uint256 _canModifySafe) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safeRights.selector).with_key(_safe).with_key(_account)
      .checked_write(_canModifySafe);
  }
}

contract Unit_SAFEEngine_Constructor is Base {
  event AddAuthorization(address _account);
  event ModifyParameters(bytes32 indexed _parameter, bytes32 indexed _collateral, bytes _data);

  function test_Set_AuthorizedAccounts() public {
    assertEq(IAuthorizable(address(safeEngine)).authorizedAccounts(deployer), 1);
  }

  function test_Set_SafeDebtCeiling() public {
    uint256 _safeDebtCeiling = safeEngine.params().safeDebtCeiling;
    assertEq(_safeDebtCeiling, type(uint256).max);
  }

  function test_Set_ContractEnabled() public {
    assertEq(safeEngine.contractEnabled(), 1);
  }

  function test_Emit_AddAuthorization() public {
    expectEmitNoIndex();
    emit AddAuthorization(deployer);
    vm.prank(deployer);
    safeEngine = new SAFEEngine(safeEngineParams);
  }

  /* TODO: add events in all constructors
  function test_Emit_ModifyParameters() public {
    vm.expectEmit(true, true, false, true);
    emit ModifyParameters('safeDebtCeiling', bytes32(0), abi.encode(type(uint256).max));

    vm.prank(deployer);
    safeEngine = new SAFEEngine(safeEngineParams);
  }
  */

  function test_Set_SAFEEngine_Params(ISAFEEngine.SAFEEngineParams memory _safeEngineParams) public {
    safeEngine = new SAFEEngine(_safeEngineParams);
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
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    safeEngine.modifyParameters(_cType, 'unrecognizedParam', abi.encode(0));
  }
}

contract Unit_SAFEEngine_ModifyCollateralBalance is Base {
  using Math for uint256;

  event TransferCollateral(bytes32 indexed _cType, address indexed _src, address indexed _dst, uint256 _wad);

  function _assumeHappyPath(uint256 _initialCollateral, int256 _wad) internal pure {
    if (_wad == 0) return;
    vm.assume(notUnderOrOverflowAdd(_initialCollateral, _wad));
  }

  function test_Set_TokenCollateral(uint256 _intialCollateral, bytes32 _collateralType, int256 _wad) public authorized {
    _assumeHappyPath(_intialCollateral, _wad);
    _mockTokenCollateral(_collateralType, account, _intialCollateral);

    safeEngine.modifyCollateralBalance(_collateralType, account, _wad);

    assertEq(safeEngine.tokenCollateral(_collateralType, account), _intialCollateral.add(_wad));
  }

  // TODO: testFail_Not_Emit_TransferCollateral_Zero

  function test_Emit_TransferCollateral_Positive(uint256 _intialCollateral, int256 _wad) public authorized {
    vm.assume(_wad >= 0);
    _assumeHappyPath(_intialCollateral, _wad);
    _mockTokenCollateral(collateralType, account, _intialCollateral);

    expectEmitNoIndex();
    emit TransferCollateral(collateralType, address(0), account, uint256(_wad));

    safeEngine.modifyCollateralBalance(collateralType, account, _wad);
  }

  function test_Emit_TransferCollateral_Negative(uint256 _intialCollateral, int256 _wad) public authorized {
    vm.assume(_wad < 0);
    _assumeHappyPath(_intialCollateral, _wad);
    _mockTokenCollateral(collateralType, account, _intialCollateral);

    expectEmitNoIndex();
    emit TransferCollateral(collateralType, account, address(0), uint256(-_wad));

    safeEngine.modifyCollateralBalance(collateralType, account, _wad);
  }

  function test_Revert_NotAuthorized(bytes32 _collateralType, int256 _wad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    safeEngine.modifyCollateralBalance(_collateralType, account, _wad);
  }
}

contract Unit_SAFEEngine_TransferCollateral is Base {
  event TransferCollateral(bytes32 indexed _collateralType, address indexed _src, address indexed _dst, uint256 _wad);

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

    vm.expectEmit(true, false, false, true);
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

    vm.expectEmit(true, false, false, true);
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

    vm.expectEmit(true, false, false, true);
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

    vm.expectEmit(true, false, false, true);
    emit CreateUnbackedDebt(debtDestination, coinDestination, _rad);

    safeEngine.createUnbackedDebt(debtDestination, coinDestination, _rad);
  }
}

contract Unit_SAFEEngine_UpdateAccumulatedRate is Base {
  using Math for uint256;

  event UpdateAccumulatedRate(bytes32 indexed _cType, address _surplusDst, int256 _rateMultiplier);

  function _assumeHappyPath(
    int256 _rateMultiplier,
    uint256 _collateralTypeDebtAmount,
    uint256 _collateralTypeAccumulatedRate,
    uint256 _surplusDstCoinBalance,
    uint256 _initialGlobalDebt
  ) internal pure {
    vm.assume(notUnderOrOverflowMul(_collateralTypeDebtAmount, _rateMultiplier));
    int256 _deltaSurplus = int256(_collateralTypeDebtAmount) * _rateMultiplier;
    vm.assume(notUnderOrOverflowAdd(_collateralTypeAccumulatedRate, _rateMultiplier));
    vm.assume(notUnderOrOverflowAdd(_initialGlobalDebt, _deltaSurplus));
    vm.assume(notUnderOrOverflowAdd(_surplusDstCoinBalance, _deltaSurplus));
  }

  function _mockValues(
    uint256 _collateralTypeDebtAmount,
    uint256 _collateralTypeAccumulatedRate,
    uint256 _surplusDstCoinBalance,
    uint256 _initialGlobalDebt
  ) internal {
    _mockCollateralType(collateralType, _collateralTypeDebtAmount, _collateralTypeAccumulatedRate, 0, 0, 0, 0);
    _mockCoinBalance(surplusDst, _surplusDstCoinBalance);
    _mockGlobalDebt(_initialGlobalDebt);
  }

  function test_Set_AccumulatedRate(
    int256 _rateMultiplier,
    uint256 _collateralTypeDebtAmount,
    uint256 _collateralTypeAccumulatedRate,
    uint256 _surplusDstCoinBalance,
    uint256 _initialGlobalDebt
  ) public authorized {
    _assumeHappyPath(
      _rateMultiplier,
      _collateralTypeDebtAmount,
      _collateralTypeAccumulatedRate,
      _surplusDstCoinBalance,
      _initialGlobalDebt
    );

    _mockValues(_collateralTypeDebtAmount, _collateralTypeAccumulatedRate, _surplusDstCoinBalance, _initialGlobalDebt);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);

    uint256 _newAccumulatedRate = safeEngine.cData(collateralType).accumulatedRate;
    assertEq(_newAccumulatedRate, _collateralTypeAccumulatedRate.add(_rateMultiplier));
  }

  function test_Set_CoinBalance(
    int256 _rateMultiplier,
    uint256 _collateralTypeDebtAmount,
    uint256 _collateralTypeAccumulatedRate,
    uint256 _surplusDstCoinBalance,
    uint256 _initialGlobalDebt
  ) public authorized {
    _assumeHappyPath(
      _rateMultiplier,
      _collateralTypeDebtAmount,
      _collateralTypeAccumulatedRate,
      _surplusDstCoinBalance,
      _initialGlobalDebt
    );

    _mockValues(_collateralTypeDebtAmount, _collateralTypeAccumulatedRate, _surplusDstCoinBalance, _initialGlobalDebt);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);

    assertEq(
      safeEngine.coinBalance(surplusDst), _surplusDstCoinBalance.add(_collateralTypeDebtAmount.mul(_rateMultiplier))
    );
  }

  function test_Set_GlobalDebt(
    int256 _rateMultiplier,
    uint256 _collateralTypeDebtAmount,
    uint256 _collateralTypeAccumulatedRate,
    uint256 _surplusDstCoinBalance,
    uint256 _initialGlobalDebt
  ) public authorized {
    _assumeHappyPath(
      _rateMultiplier,
      _collateralTypeDebtAmount,
      _collateralTypeAccumulatedRate,
      _surplusDstCoinBalance,
      _initialGlobalDebt
    );

    _mockValues(_collateralTypeDebtAmount, _collateralTypeAccumulatedRate, _surplusDstCoinBalance, _initialGlobalDebt);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);

    assertEq(safeEngine.globalDebt(), _initialGlobalDebt.add(_collateralTypeDebtAmount.mul(_rateMultiplier)));
  }

  function test_Emit_UpdateAccumulatedRate(
    int256 _rateMultiplier,
    uint256 _collateralTypeDebtAmount,
    uint256 _collateralTypeAccumulatedRate,
    uint256 _surplusDstCoinBalance,
    uint256 _initialGlobalDebt
  ) public authorized {
    _assumeHappyPath(
      _rateMultiplier,
      _collateralTypeDebtAmount,
      _collateralTypeAccumulatedRate,
      _surplusDstCoinBalance,
      _initialGlobalDebt
    );

    _mockValues(_collateralTypeDebtAmount, _collateralTypeAccumulatedRate, _surplusDstCoinBalance, _initialGlobalDebt);

    vm.expectEmit(true, false, false, true);
    emit UpdateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);
  }

  function test_Revert_NotAuthorized(int256 _rateMultiplier) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);
  }

  function test_Revert_ContractNotEnabled(int256 _rateMultiplier) public authorized {
    uint256 _enabled = 0;
    _mockContractEnabled(_enabled);

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
    _mockParams(type(uint256).max, type(uint256).max);
    _mockSafeData(collateralType, safe, _scenario.safeData);
    _mockCollateralType(collateralType, _scenario.cData);
    _mockCollateralParams(
      collateralType, ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: type(uint256).max, debtFloor: 0})
    );
    _mockCoinBalance(debtDestination, _scenario.coinBalance);
    _mockTokenCollateral(collateralType, src, _scenario.collateralBalance);
    _mockGlobalDebt(_scenario.globalDebt);
    _mockCanModifySafe(src, safe, 1);
    _mockCanModifySafe(debtDestination, safe, 1);
  }

  function test_Set_SafeDataLockedCollateral(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newLockedCollateral = safeEngine.safes(collateralType, safe).lockedCollateral;
    assertEq(_newLockedCollateral, _scenario.safeData.lockedCollateral.add(_scenario.deltaCollateral));
  }

  function test_Set_SafeDataGeneratedDebt(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newGeneratedDebt = safeEngine.safes(collateralType, safe).generatedDebt;
    assertEq(_newGeneratedDebt, _scenario.safeData.generatedDebt.add(_scenario.deltaDebt));
  }

  function test_Set_CollateralTypeDataDebtAmount(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    uint256 _newDebtAmount = safeEngine.cData(collateralType).debtAmount;

    assertEq(_newDebtAmount, _scenario.cData.debtAmount.add(_scenario.deltaDebt));
  }

  function test_Set_GlobalDebt(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    assertEq(
      safeEngine.globalDebt(), _scenario.globalDebt.add(_scenario.cData.accumulatedRate.mul(_scenario.deltaDebt))
    );
  }

  function test_Set_TokenCollateral(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    assertEq(
      safeEngine.tokenCollateral(collateralType, src), _scenario.collateralBalance.sub(_scenario.deltaCollateral)
    );
  }

  function test_Set_CoinBalance(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    assertEq(
      safeEngine.coinBalance(debtDestination),
      _scenario.coinBalance.add(_scenario.cData.accumulatedRate.mul(_scenario.deltaDebt))
    );
  }

  function test_Emit_ModifySAFECollateralization(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectEmit(true, false, false, true);
    emit ModifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_ContractNotEnabled() public {
    uint256 _enabled = 0;
    _mockContractEnabled(_enabled);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, 0);
  }

  function test_Revert_CollateralNotInitialized() public {
    _mockCollateralType({
      _collateralType: collateralType,
      _debtAmount: 0,
      _accumulatedRate: 0,
      _safetyPrice: 0,
      _debtCeiling: 0,
      _debtFloor: 0,
      _liquidationPrice: 0
    });

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
    _mockParams(type(uint256).max, _globalDebtCeiling);

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
    _mockCanModifySafe(debtDestination, address(this), 1);
    _mockCanModifySafe(safe, address(this), 0);
    vm.assume(_scenario.deltaDebt > 0 || _scenario.deltaCollateral < 0);

    vm.expectRevert(ISAFEEngine.SAFEEng_NotSAFEAllowed.selector);

    safeEngine.modifySAFECollateralization(
      collateralType, safe, src, debtDestination, _scenario.deltaCollateral, _scenario.deltaDebt
    );
  }

  function test_Revert_NotAllowedCollateralSrc(ModifySAFECollateralizationScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    _mockCanModifySafe(src, safe, 0);
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
    _mockCanModifySafe(debtDestination, safe, 0);
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
    _mockParams(_safeDebtCeiling, type(uint256).max);

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

  function _assumeHappyPath(
    int256 _deltaCollateral,
    int256 _deltaDebt
  )
    internal
    returns (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    )
  {
    if (_deltaCollateral < 0) {
      vm.assume(_deltaCollateral != type(int256).min);
      _dstInitialLockedCollateral = uint256(-_deltaCollateral);
    } else {
      _srcInitialLockedCollateral = uint256(_deltaCollateral);
    }

    if (_deltaDebt < 0) {
      vm.assume(_deltaDebt != type(int256).min);
      _dstInitialGeneratedDebt = uint256(-_deltaDebt);
      vm.assume(_srcInitialLockedCollateral.sub(_deltaCollateral) >= uint256(-_deltaDebt));
    } else {
      _srcInitialGeneratedDebt = uint256(_deltaDebt);
      vm.assume(_dstInitialLockedCollateral.add(_deltaCollateral) >= uint256(_deltaDebt));
    }

    _mockCanModifySafe(src, account, 1);
    _mockCanModifySafe(dst, account, 1);
  }

  function _mockValues(
    uint256 _srcInitialLockedCollateral,
    uint256 _srcInitialGeneratedDebt,
    uint256 _dstInitialLockedCollateral,
    uint256 _dstInitialGeneratedDebt,
    uint256 _safetyPrice,
    uint256 _accumulatedRate
  ) internal {
    _mockSafeData(
      collateralType,
      src,
      ISAFEEngine.SAFE({lockedCollateral: _srcInitialLockedCollateral, generatedDebt: _srcInitialGeneratedDebt})
    );
    _mockSafeData(
      collateralType,
      dst,
      ISAFEEngine.SAFE({lockedCollateral: _dstInitialLockedCollateral, generatedDebt: _dstInitialGeneratedDebt})
    );
    _mockCollateralType({
      _collateralType: collateralType,
      _debtAmount: 0,
      _accumulatedRate: _accumulatedRate,
      _safetyPrice: _safetyPrice,
      _debtCeiling: 0,
      _debtFloor: 0,
      _liquidationPrice: 0
    });
  }

  function test_Set_SrcSafeLockedCollateral(int256 _deltaCollateral, int256 _deltaDebt) public {
    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(_deltaCollateral, _deltaDebt);

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);

    uint256 _srcLockedCollateral = safeEngine.safes(collateralType, src).lockedCollateral;
    assertEq(_srcLockedCollateral, _srcInitialLockedCollateral.sub(_deltaCollateral));
  }

  function test_Set_SrcSafeGeneratedDebt(int256 _deltaCollateral, int256 _deltaDebt) public {
    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(_deltaCollateral, _deltaDebt);

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);

    uint256 _srcGeneratedDebt = safeEngine.safes(collateralType, src).generatedDebt;
    assertEq(_srcGeneratedDebt, _srcInitialGeneratedDebt.sub(_deltaDebt));
  }

  function test_Set_DstSafeLockedCollateral(int256 _deltaCollateral, int256 _deltaDebt) public {
    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(_deltaCollateral, _deltaDebt);

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);

    uint256 _dstLockedCollateral = safeEngine.safes(collateralType, dst).lockedCollateral;
    assertEq(_dstLockedCollateral, _dstInitialLockedCollateral.add(_deltaCollateral));
  }

  function test_Set_DstSafeGeneratedDebt(int256 _deltaCollateral, int256 _deltaDebt) public {
    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(_deltaCollateral, _deltaDebt);

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);

    uint256 _dstGeneratedDebt = safeEngine.safes(collateralType, dst).generatedDebt;
    assertEq(_dstGeneratedDebt, _dstInitialGeneratedDebt.add(_deltaDebt));
  }

  function test_Emit_TransferSAFECollateralAndDebt(int256 _deltaCollateral, int256 _deltaDebt) public {
    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(_deltaCollateral, _deltaDebt);

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );

    vm.expectEmit(true, false, false, true);
    emit TransferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);
  }

  function test_Revert_CannotModifySafe(uint256 _canModifySrcSafe, uint256 _canModifyDstSafe) public {
    vm.assume(_canModifySrcSafe != 1 || _canModifyDstSafe != 1);

    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(10, 10);

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );

    _mockCanModifySafe(src, account, _canModifySrcSafe);
    _mockCanModifySafe(dst, account, _canModifyDstSafe);

    vm.expectRevert(ISAFEEngine.SAFEEng_NotSAFEAllowed.selector);
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, 10, 10);
  }

  function test_Revert_NotSafeSrc(uint256 safetyPrice, uint256 _accumulatedRate) public {
    vm.assume(notOverflowMul(_accumulatedRate, 10));
    vm.assume(safetyPrice < _accumulatedRate);
    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(-10, -10);

    _mockValues(
      _srcInitialLockedCollateral,
      _srcInitialGeneratedDebt,
      _dstInitialLockedCollateral,
      _dstInitialGeneratedDebt,
      safetyPrice,
      _accumulatedRate
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_NotSafeSrc.selector);
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, -10, -10);
  }

  function test_Revert_NotSafeDst(uint256 safetyPrice, uint256 _accumulatedRate) public {
    vm.assume(notOverflowMul(_accumulatedRate, 10));
    vm.assume(safetyPrice < _accumulatedRate);
    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(10, 10);

    _mockValues(
      _srcInitialLockedCollateral,
      _srcInitialGeneratedDebt,
      _dstInitialLockedCollateral,
      _dstInitialGeneratedDebt,
      safetyPrice,
      _accumulatedRate
    );

    vm.expectRevert(ISAFEEngine.SAFEEng_NotSafeDst.selector);
    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, 10, 10);
  }

  function test_Revert_DustSrc(int256 _deltaCollateral, int256 _deltaDebt, uint256 _debtFloor) public {
    vm.assume(_deltaCollateral < 0 && _deltaDebt < 0);

    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(_deltaCollateral, _deltaDebt);
    vm.assume(_debtFloor > _srcInitialGeneratedDebt.sub(_deltaDebt));

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cParams.selector).with_key(collateralType).depth(1)
      .checked_write(_debtFloor);

    vm.expectRevert(ISAFEEngine.SAFEEng_DustSrc.selector);

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);
  }

  function test_Revert_DustDst(int256 _deltaCollateral, int256 _deltaDebt, uint256 _debtFloor) public {
    vm.assume(_deltaCollateral > 0 && _deltaDebt > 0);

    (
      uint256 _srcInitialLockedCollateral,
      uint256 _srcInitialGeneratedDebt,
      uint256 _dstInitialLockedCollateral,
      uint256 _dstInitialGeneratedDebt
    ) = _assumeHappyPath(_deltaCollateral, _deltaDebt);
    vm.assume(_debtFloor > _dstInitialLockedCollateral.add(_deltaDebt));

    _mockValues(
      _srcInitialLockedCollateral, _srcInitialGeneratedDebt, _dstInitialLockedCollateral, _dstInitialGeneratedDebt, 1, 1
    );
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.cParams.selector).with_key(collateralType).depth(1)
      .checked_write(_debtFloor);

    vm.expectRevert(ISAFEEngine.SAFEEng_DustDst.selector);

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);
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

  function _assumeHappyPath(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) internal pure {
    vm.assume(notUnderOrOverflowMul(_accumulatedRate, _deltaDebt));

    vm.assume(notUnderOrOverflowAdd(_initialLockedCollateral, _deltaCollateral));
    vm.assume(notUnderOrOverflowSub(_tokenCollateral, _deltaCollateral));

    vm.assume(notUnderOrOverflowAdd(_initialGeneratedDebt, _deltaDebt));
    vm.assume(notUnderOrOverflowSub(_debtBalance, _deltaDebt));
  }

  function _mockValues(
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance,
    uint256 _accumulatedRate
  ) internal {
    _mockSafeData(collateralType, safe, _initialLockedCollateral, _initialGeneratedDebt);
    _mockCollateralType({
      _collateralType: collateralType,
      _debtAmount: _initialGeneratedDebt,
      _accumulatedRate: _accumulatedRate,
      _safetyPrice: 1,
      _debtCeiling: 0,
      _debtFloor: 0,
      _liquidationPrice: 0
    });
    _mockTokenCollateral(collateralType, collateralSource, _tokenCollateral);
    _mockGlobalUnbackedDebt(_debtBalance);
    _mockDebtBalance(debtDestination, _debtBalance);
  }

  function test_Set_SafeLockedCollateral(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) public authorized {
    _assumeHappyPath(
      _deltaCollateral,
      _deltaDebt,
      _accumulatedRate,
      _initialLockedCollateral,
      _initialGeneratedDebt,
      _tokenCollateral,
      _debtBalance
    );

    _mockValues(_initialLockedCollateral, _initialGeneratedDebt, _tokenCollateral, _debtBalance, _accumulatedRate);

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );

    uint256 _lockedCollateral = safeEngine.safes(collateralType, safe).lockedCollateral;
    assertEq(_lockedCollateral, _initialLockedCollateral.add(_deltaCollateral));
  }

  function test_Set_GeneratedDebt(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) public authorized {
    _assumeHappyPath(
      _deltaCollateral,
      _deltaDebt,
      _accumulatedRate,
      _initialLockedCollateral,
      _initialGeneratedDebt,
      _tokenCollateral,
      _debtBalance
    );

    _mockValues(_initialLockedCollateral, _initialGeneratedDebt, _tokenCollateral, _debtBalance, _accumulatedRate);

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );

    uint256 _generatedDebt = safeEngine.safes(collateralType, safe).generatedDebt;
    assertEq(_generatedDebt, _initialGeneratedDebt.add(_deltaDebt));
  }

  function test_Set_DebtAmount(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) public authorized {
    _assumeHappyPath(
      _deltaCollateral,
      _deltaDebt,
      _accumulatedRate,
      _initialLockedCollateral,
      _initialGeneratedDebt,
      _tokenCollateral,
      _debtBalance
    );

    _mockValues(_initialLockedCollateral, _initialGeneratedDebt, _tokenCollateral, _debtBalance, _accumulatedRate);

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );

    uint256 _debtAmount = safeEngine.cData(collateralType).debtAmount;
    assertEq(_debtAmount, _initialGeneratedDebt.add(_deltaDebt));
  }

  function test_Set_TokenCollateral(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) public authorized {
    _assumeHappyPath(
      _deltaCollateral,
      _deltaDebt,
      _accumulatedRate,
      _initialLockedCollateral,
      _initialGeneratedDebt,
      _tokenCollateral,
      _debtBalance
    );

    _mockValues(_initialLockedCollateral, _initialGeneratedDebt, _tokenCollateral, _debtBalance, _accumulatedRate);

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );

    uint256 _newTokenCollateral = safeEngine.tokenCollateral(collateralType, collateralSource);
    assertEq(_newTokenCollateral, _tokenCollateral.sub(_deltaCollateral));
  }

  function test_Set_DebtBalance(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) public authorized {
    _assumeHappyPath(
      _deltaCollateral,
      _deltaDebt,
      _accumulatedRate,
      _initialLockedCollateral,
      _initialGeneratedDebt,
      _tokenCollateral,
      _debtBalance
    );

    _mockValues(_initialLockedCollateral, _initialGeneratedDebt, _tokenCollateral, _debtBalance, _accumulatedRate);

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );

    uint256 _newDebtBalance = safeEngine.debtBalance(debtDestination);
    assertEq(_newDebtBalance, _debtBalance.sub(_accumulatedRate.mul(_deltaDebt)));
  }

  function test_Set_GlobalUnbackedDebt(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) public authorized {
    _assumeHappyPath(
      _deltaCollateral,
      _deltaDebt,
      _accumulatedRate,
      _initialLockedCollateral,
      _initialGeneratedDebt,
      _tokenCollateral,
      _debtBalance
    );

    _mockValues(_initialLockedCollateral, _initialGeneratedDebt, _tokenCollateral, _debtBalance, _accumulatedRate);

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );

    assertEq(safeEngine.globalUnbackedDebt(), _debtBalance.sub(_accumulatedRate.mul(_deltaDebt)));
  }

  function test_Emit_ConfiscateSAFECollateralAndDebt(
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _accumulatedRate,
    uint256 _initialLockedCollateral,
    uint256 _initialGeneratedDebt,
    uint256 _tokenCollateral,
    uint256 _debtBalance
  ) public authorized {
    _assumeHappyPath(
      _deltaCollateral,
      _deltaDebt,
      _accumulatedRate,
      _initialLockedCollateral,
      _initialGeneratedDebt,
      _tokenCollateral,
      _debtBalance
    );

    _mockValues(_initialLockedCollateral, _initialGeneratedDebt, _tokenCollateral, _debtBalance, _accumulatedRate);

    vm.expectEmit(true, false, false, true);
    emit ConfiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralSource, debtDestination, _deltaCollateral, _deltaDebt
    );
  }
}

contract Unit_SAFEEngine_ApproveSAFEModification is Base {
  event ApproveSAFEModification(address _sender, address _account);

  function test_Set_SafeRights(address _sender, address _account) public {
    vm.prank(_sender);

    safeEngine.approveSAFEModification(_account);

    assertEq(safeEngine.safeRights(_sender, _account), 1);
  }

  function test_Emit_ApproveSAFEModification(address _sender, address _account) public {
    vm.prank(_sender);

    expectEmitNoIndex();
    emit ApproveSAFEModification(_sender, _account);

    safeEngine.approveSAFEModification(_account);
  }
}

contract Unit_SAFEEngine_DenySAFEModification is Base {
  event DenySAFEModification(address _sender, address _account);

  function test_Set_SafeRights(address _sender, address _account) public {
    _mockCanModifySafe(_sender, _account, 1);

    vm.prank(_sender);
    safeEngine.denySAFEModification(_account);

    assertEq(safeEngine.safeRights(_sender, _account), 0);
  }

  function test_Emit_DenySAFEModification(address _sender, address _account) public {
    _mockCanModifySafe(_sender, _account, 1);

    expectEmitNoIndex();
    emit DenySAFEModification(_sender, _account);

    vm.prank(_sender);
    safeEngine.denySAFEModification(_account);
  }
}

contract Unit_SAFEEngine_CanModifySafe is Base {
  function test_Return_SameAccountCanModify(address _account) public {
    // Even though we deny it, because it is the same account it should be able to modify
    _mockCanModifySafe(_account, _account, 0);

    assertEq(safeEngine.canModifySAFE(_account, _account), true);
  }

  function test_Return_CanModify(address _sender, address _account) public {
    _mockCanModifySafe(_sender, _account, 1);

    assertEq(safeEngine.canModifySAFE(_account, _account), true);
  }

  function test_Return_CannotModify(address _sender, address _account) public {
    vm.assume(_sender != _account);
    _mockCanModifySafe(_sender, _account, 0);

    assertEq(safeEngine.canModifySAFE(_account, _account), true);
  }
}

contract Unit_SAFEEngine_InitializeCollateralType is Base {
  ISAFEEngine.SAFEEngineCollateralParams safeEngineCollateralParams =
    ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});

  event InitializeCollateralType(bytes32 _collateralType);

  function test_Set_AccummulatedRate(bytes32 _collateralType) public authorized {
    safeEngine.initializeCollateralType(_collateralType, safeEngineCollateralParams);

    uint256 _accumulatedRate = safeEngine.cData(_collateralType).accumulatedRate;
    assertEq(_accumulatedRate, RAY);
  }

  function test_Emit_InitializeCollateralType(bytes32 _collateralType) public authorized {
    expectEmitNoIndex();
    emit InitializeCollateralType(_collateralType);

    safeEngine.initializeCollateralType(_collateralType, safeEngineCollateralParams);
  }

  function test_Revert_NotAuthorized(bytes32 _collateralType) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    safeEngine.initializeCollateralType(_collateralType, safeEngineCollateralParams);
  }

  function test_Revert_CollateralTypeAlreadyExists(bytes32 _collateralType, uint256 _accumulatedRate) public authorized {
    vm.assume(_accumulatedRate > 0);
    _mockCollateralType({
      _collateralType: _collateralType,
      _debtAmount: 0,
      _accumulatedRate: _accumulatedRate,
      _safetyPrice: 0,
      _debtCeiling: 0,
      _debtFloor: 0,
      _liquidationPrice: 0
    });

    vm.expectRevert(ISAFEEngine.SAFEEng_CollateralTypeAlreadyExists.selector);

    safeEngine.initializeCollateralType(_collateralType, safeEngineCollateralParams);
  }
}
