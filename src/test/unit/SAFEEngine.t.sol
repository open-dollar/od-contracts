// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Math, RAY} from '@libraries/Math.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IDisableable} from '@interfaces/IDisableable.sol';
import {IAuthorizable} from '@interfaces/IAuthorizable.sol';
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  // Test addresses
  address deployer = newAddress();
  address safe = newAddress();
  address collateralCounterparty = newAddress();
  address debtCounterparty = newAddress();
  address src = newAddress();
  address dst = newAddress();
  address account = newAddress();
  address debtDestination = newAddress();
  address coinDestination = newAddress();
  address surplusDst = newAddress();

  // Test collateral type
  bytes32 collateralType = bytes32('collateralTest');

  ISAFEEngine safeEngine;

  function setUp() public virtual {
    vm.prank(deployer);
    safeEngine = new SAFEEngine();
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

  function _mockSafeData(
    bytes32 _collateralType,
    address _safe,
    uint256 _lockedCollateral,
    uint256 _generatedDebt
  ) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safes.selector).with_key(_collateralType).with_key(_safe).depth(
      0
    ).checked_write(_lockedCollateral);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safes.selector).with_key(_collateralType).with_key(_safe).depth(
      1
    ).checked_write(_generatedDebt);
  }

  function _mockCollateralType(
    bytes32 _collateralType,
    uint256 _debtAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _debtCeiling,
    uint256 _debtFloor,
    uint256 _liquidationPrice
  ) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(_collateralType).depth(0)
      .checked_write(_debtAmount);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(_collateralType).depth(1)
      .checked_write(_accumulatedRate);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(_collateralType).depth(2)
      .checked_write(_safetyPrice);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(_collateralType).depth(3)
      .checked_write(_debtCeiling);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(_collateralType).depth(4)
      .checked_write(_debtFloor);
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(_collateralType).depth(5)
      .checked_write(_liquidationPrice);
  }

  function _mockGlobalDebtCeiling(uint256 _globalDebtCeiling) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.globalDebtCeiling.selector).checked_write(_globalDebtCeiling);
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

  function _mockSafeDebtCeiling(uint256 _safeDebtCeiling) internal {
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.safeDebtCeiling.selector).checked_write(_safeDebtCeiling);
  }
}

contract Unit_SAFEEngine_Constructor is Base {
  event AddAuthorization(address _account);
  event ModifyParameters(bytes32 _parameter, uint256 _data);

  function test_Set_AuthorizedAccounts() public {
    assertEq(IAuthorizable(address(safeEngine)).authorizedAccounts(deployer), 1);
  }

  function test_Set_SafeDebtCeiling() public {
    assertEq(safeEngine.safeDebtCeiling(), type(uint256).max);
  }

  function test_Set_ContractEnabled() public {
    assertEq(safeEngine.contractEnabled(), 1);
  }

  function test_Emit_AddAuthorization() public {
    expectEmitNoIndex();
    emit AddAuthorization(deployer);
    vm.prank(deployer);
    safeEngine = new SAFEEngine();
  }

  function test_Emit_ModifyParameters() public {
    expectEmitNoIndex();
    emit ModifyParameters('safeDebtCeiling', type(uint256).max);

    vm.prank(deployer);
    safeEngine = new SAFEEngine();
  }
}

contract Unit_SAFEEngine_ModifyCollateralBalance is Base {
  using Math for uint256;

  event ModifyCollateralBalance(bytes32 indexed _collateralType, address indexed _account, int256 _wad);

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

  function test_Emit_ModifyCollateralBalance(uint256 _intialCollateral, int256 _wad) public authorized {
    _assumeHappyPath(_intialCollateral, _wad);
    _mockTokenCollateral(collateralType, account, _intialCollateral);

    expectEmitNoIndex();
    emit ModifyCollateralBalance(collateralType, account, _wad);

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
    vm.assume(notOverflow(_initialCollateralDst, _wad));
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

    vm.stopPrank();
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

    vm.stopPrank();
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

    vm.stopPrank();
    vm.prank(src);
    safeEngine.transferCollateral(collateralType, src, dst, _wad);
  }

  function test_Revert_CannotModifySAFE(bytes32 collateralType, uint256 _wad) public {
    vm.expectRevert(ISAFEEngine.NotSAFEAllowed.selector);

    vm.prank(dst);
    safeEngine.transferCollateral(collateralType, src, dst, _wad);
  }
}

contract Unit_SAFEEngine_TransferInternalCoins is Base {
  event TransferInternalCoins(address indexed _src, address indexed _dst, uint256 _rad);

  function _assumeHappyPath(uint256 _initialBalanceSrc, uint256 _initialBalanceDst, uint256 _rad) internal pure {
    vm.assume(notUnderflow(_initialBalanceSrc, _rad));
    vm.assume(notOverflow(_initialBalanceDst, _rad));
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
    vm.expectRevert(ISAFEEngine.NotSAFEAllowed.selector);

    vm.prank(dst);
    safeEngine.transferInternalCoins(src, dst, _rad);
  }
}

contract Unit_SAFEEngine_SettleDebt is Base {
  event SettleDebt(
    address indexed _account,
    uint256 _rad,
    uint256 _debtBalance,
    uint256 _coinBalance,
    uint256 _globalUnbackedDebt,
    uint256 _globalDebt
  );

  function _assumeHappyPath(
    uint256 _initialDebtBalance,
    uint256 _initialCoinBalance,
    uint256 _initialGlobalUnbackedDebt,
    uint256 _globalDebt,
    uint256 _rad
  ) internal pure {
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
    emit SettleDebt(
      account,
      _rad,
      _initialDebtBalance - _rad,
      _initialCoinBalance - _rad,
      _initialGlobalUnbackedDebt - _rad,
      _globalDebt - _rad
    );

    vm.prank(account);
    safeEngine.settleDebt(_rad);
  }
}

contract Unit_SAFEEngine_CreateUnbackedDebt is Base {
  event CreateUnbackedDebt(
    address indexed _debtDestination,
    address indexed _coinDestination,
    uint256 _rad,
    uint256 _debtDstBalance,
    uint256 _coinDstBalance,
    uint256 _globalUnbackedDebt,
    uint256 _globalDebt
  );

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
    vm.assume(notOverflow(_initialDebtBalance, _rad));
    vm.assume(notOverflow(_initialCoinBalance, _rad));
    vm.assume(notOverflow(_initialGlobalUnbackedDebt, _rad));
    vm.assume(notOverflow(_globalDebt, _rad));
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

    safeEngine.createUnbackedDebt(debtDestination, coinDestination, _rad);

    assertEq(safeEngine.globalDebt(), _globalDebt + _rad);
  }
}

contract Unit_SAFEEngine_UpdateAccumulatedRate is Base {
  using Math for uint256;

  event UpdateAccumulatedRate(
    bytes32 indexed collateralType,
    address _surplusDst,
    int256 _rateMultiplier,
    uint256 _dstCoinBalance,
    uint256 _globalDebt
  );

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

    (, uint256 _newAccumulatedRate,,,,) = safeEngine.collateralTypes(collateralType);
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

    int256 _deltaSurplus = _collateralTypeDebtAmount.mul(_rateMultiplier);
    vm.expectEmit(true, false, false, true);
    emit UpdateAccumulatedRate(
      collateralType,
      surplusDst,
      _rateMultiplier,
      _surplusDstCoinBalance.add(_deltaSurplus),
      _initialGlobalDebt.add(_deltaSurplus)
    );

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);
  }

  function test_Revert_NotAuthorized(int256 _rateMultiplier) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);
  }

  function test_Revert_ContractNotEnabled(int256 _rateMultiplier, uint256 _enabled) public authorized {
    vm.assume(_enabled != 1);
    _mockContractEnabled(_enabled);

    vm.expectRevert(bytes('SAFEEngine/contract-not-enabled'));

    safeEngine.updateAccumulatedRate(collateralType, surplusDst, _rateMultiplier);
  }
}

contract Unit_SAFEEngine_ModifySafeCollateralization is Base {
  using Math for uint256;

  event ModifySAFECollateralization(
    bytes32 indexed _collateralType,
    address indexed _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _lockedCollateral,
    uint256 _generatedDebt,
    uint256 _globalDebt
  );

  function _assumeHappyPathLockedCollateral(
    int256 _deltaCollateral,
    uint256 _initialSafeLockedCollateral,
    uint256 _initialTokenCollateral
  ) internal pure {
    vm.assume(notUnderOrOverflowAdd(_initialSafeLockedCollateral, _deltaCollateral));
    vm.assume(notUnderOrOverflowSub(_initialTokenCollateral, _deltaCollateral));
  }

  function _mockValuesLockedCollateral(uint256 _initialSafeLockedCollateral, uint256 _initialTokenCollateral) internal {
    _mockSafeData({
      _collateralType: collateralType,
      _safe: safe,
      _lockedCollateral: _initialSafeLockedCollateral,
      _generatedDebt: 0
    });
    _mockCollateralType({
      _collateralType: collateralType,
      _debtAmount: 0,
      _accumulatedRate: 1,
      _safetyPrice: 0,
      _debtCeiling: 0,
      _debtFloor: 0,
      _liquidationPrice: 0
    });
    _mockCanModifySafe(src, safe, 1);
    _mockTokenCollateral(collateralType, src, _initialTokenCollateral);
  }

  function _assumeHappyPathDeltaDebt(
    int256 _deltaDebt,
    uint256 _initialGeneratedDebt,
    uint256 _initialDebtAmount,
    uint256 _initialGlobalDebt,
    uint256 _accumulatedRate
  ) internal pure {
    vm.assume(_initialDebtAmount <= _initialGlobalDebt);
    vm.assume(_accumulatedRate > 0);
    vm.assume(_deltaDebt != type(int256).min && _deltaDebt != 0);
    vm.assume(uint256(_deltaDebt) <= uint256(type(int256).max) / _accumulatedRate);
    vm.assume(notOverflowMul(uint256(_deltaDebt), _accumulatedRate));
    vm.assume(notUnderOrOverflowAdd(_initialGeneratedDebt, _deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_initialDebtAmount, _deltaDebt));
    vm.assume(notUnderOrOverflowAdd(_initialGlobalDebt, _deltaDebt));
    vm.assume(notOverflowMul(_initialGlobalDebt.add(_deltaDebt), _accumulatedRate));
    vm.assume(notOverflowMul(_initialGeneratedDebt.add(_deltaDebt), _accumulatedRate));
  }

  function _mockValuesDeltaDebt(
    int256 _deltaDebt,
    uint256 _initialGeneratedDebt,
    uint256 _initialDebtAmount,
    uint256 _initialGlobalDebt,
    uint256 _accumulatedRate
  ) internal returns (uint256 _lockedCollateral, uint256 _initialCoinBalanceDebtDst, uint256 collateralTypeDebtCeiling) {
    if (_initialGeneratedDebt > 0) {
      _lockedCollateral = uint256(_initialGeneratedDebt);
    }
    if (_deltaDebt >= 0) {
      collateralTypeDebtCeiling = (_initialGlobalDebt + uint256(_deltaDebt)) * _accumulatedRate;
      _lockedCollateral = (_lockedCollateral + uint256(_deltaDebt)) * _accumulatedRate;
    } else {
      _initialCoinBalanceDebtDst = _accumulatedRate * uint256(-_deltaDebt);
    }

    _mockSafeData({
      _collateralType: collateralType,
      _safe: safe,
      _lockedCollateral: _lockedCollateral,
      _generatedDebt: _initialGeneratedDebt
    });
    _mockCollateralType({
      _collateralType: collateralType,
      _debtAmount: _initialDebtAmount,
      _accumulatedRate: _accumulatedRate,
      _safetyPrice: 1,
      _debtCeiling: collateralTypeDebtCeiling,
      _debtFloor: 0,
      _liquidationPrice: 0
    });
    _mockCanModifySafe(src, safe, 1);
    _mockCanModifySafe(debtDestination, safe, 1);
    _mockGlobalDebtCeiling(collateralTypeDebtCeiling);
    _mockCoinBalance(debtDestination, _initialCoinBalanceDebtDst);
    _mockGlobalDebt(_initialGlobalDebt);

    return (_lockedCollateral, _initialCoinBalanceDebtDst, collateralTypeDebtCeiling);
  }

  function _assumeRevertCommon(
    int256 _deltaDebt,
    int256 _deltaCollateral
  ) internal pure returns (uint256 _initialDebt, uint256 _initialLockedCollateral) {
    if (_deltaDebt < 0) {
      vm.assume(_deltaDebt != type(int256).min);
      _initialDebt = uint256(-_deltaDebt);
    }
    if (_deltaCollateral < 0) {
      vm.assume(_deltaCollateral != type(int256).min);
      _initialLockedCollateral = uint256(-_deltaCollateral);
    }
  }

  function _mockRevertValues(
    uint256 _globalDebtCeiling,
    uint256 _initialLockedCollateral,
    uint256 _initialDebtAmount,
    uint256 _collateralTypeDebtCeiling,
    uint256 _debtFloor
  ) internal {
    _mockGlobalDebtCeiling(_globalDebtCeiling);
    _mockGlobalDebt(_initialDebtAmount);
    _mockSafeData({
      _collateralType: collateralType,
      _safe: safe,
      _lockedCollateral: _initialLockedCollateral,
      _generatedDebt: _initialDebtAmount
    });
    _mockCollateralType({
      _collateralType: collateralType,
      _debtAmount: _initialDebtAmount,
      _accumulatedRate: 1,
      _safetyPrice: 1,
      _debtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: _debtFloor,
      _liquidationPrice: 0
    });

    _mockCanModifySafe(src, safe, 1);
    _mockCanModifySafe(debtDestination, safe, 1);
  }

  function test_Set_SafeDataLockedCollateral(
    int256 _deltaCollateral,
    uint256 _initialSafeLockedCollateral,
    uint256 _initialTokenCollateral
  ) public {
    _assumeHappyPathLockedCollateral(_deltaCollateral, _initialSafeLockedCollateral, _initialTokenCollateral);
    _mockValuesLockedCollateral(_initialSafeLockedCollateral, _initialTokenCollateral);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, 0);

    (uint256 _newLockedCollateral,) = safeEngine.safes(collateralType, safe);
    assertEq(_newLockedCollateral, _initialSafeLockedCollateral.add(_deltaCollateral));
  }

  function test_Set_SafeDataGeneratedDebt(
    int256 _deltaDebt,
    uint256 _initialGeneratedDebt,
    uint256 _initialDebtAmount,
    uint256 _initialGlobalDebt,
    uint256 _accumulatedRate
  ) public {
    _assumeHappyPathDeltaDebt(
      _deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate
    );

    _mockValuesDeltaDebt(_deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, _deltaDebt);

    (, uint256 _newGeneratedDebt) = safeEngine.safes(collateralType, safe);
    assertEq(_newGeneratedDebt, _initialGeneratedDebt.add(_deltaDebt));
  }

  function test_Set_CollateralTypeDataDebtAmount(
    int256 _deltaDebt,
    uint256 _initialGeneratedDebt,
    uint256 _initialDebtAmount,
    uint256 _initialGlobalDebt,
    uint256 _accumulatedRate
  ) public {
    _assumeHappyPathDeltaDebt(
      _deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate
    );

    _mockValuesDeltaDebt(_deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, _deltaDebt);

    (uint256 _newDebtAmount,,,,,) = safeEngine.collateralTypes(collateralType);

    assertEq(_newDebtAmount, _initialDebtAmount.add(_deltaDebt));
  }

  function test_Set_GlobalDebt(
    int256 _deltaDebt,
    uint256 _initialGeneratedDebt,
    uint256 _initialDebtAmount,
    uint256 _initialGlobalDebt,
    uint256 _accumulatedRate
  ) public {
    _assumeHappyPathDeltaDebt(
      _deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate
    );

    _mockValuesDeltaDebt(_deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, _deltaDebt);

    assertEq(safeEngine.globalDebt(), _initialGlobalDebt.add(_accumulatedRate.mul(_deltaDebt)));
  }

  function test_Set_TokenCollateral(
    int256 _deltaCollateral,
    uint256 _initialSafeLockedCollateral,
    uint256 _initialTokenCollateral
  ) public {
    _assumeHappyPathLockedCollateral(_deltaCollateral, _initialSafeLockedCollateral, _initialTokenCollateral);
    _mockValuesLockedCollateral(_initialSafeLockedCollateral, _initialTokenCollateral);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, 0);

    assertEq(safeEngine.tokenCollateral(collateralType, src), _initialTokenCollateral.sub(_deltaCollateral));
  }

  function test_Set_CoinBalance(
    int256 _deltaDebt,
    uint256 _initialGeneratedDebt,
    uint256 _initialDebtAmount,
    uint256 _initialGlobalDebt,
    uint256 _accumulatedRate
  ) public {
    _assumeHappyPathDeltaDebt(
      _deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate
    );
    (, uint256 _initialCoinBalanceDebtDst,) =
      _mockValuesDeltaDebt(_deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate);

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, _deltaDebt);

    assertEq(safeEngine.coinBalance(debtDestination), _initialCoinBalanceDebtDst.add(_accumulatedRate.mul(_deltaDebt)));
  }

  function test_Emit_ModifySAFECollateralization_DeltaDebt(
    int256 _deltaDebt,
    uint256 _initialGeneratedDebt,
    uint256 _initialDebtAmount,
    uint256 _initialGlobalDebt,
    uint256 _accumulatedRate
  ) public {
    _assumeHappyPathDeltaDebt(
      _deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate
    );
    (uint256 _lockedCollateral,,) =
      _mockValuesDeltaDebt(_deltaDebt, _initialGeneratedDebt, _initialDebtAmount, _initialGlobalDebt, _accumulatedRate);

    uint256 _newGlobalDebt = _initialGlobalDebt.add(_accumulatedRate.mul(_deltaDebt));
    vm.expectEmit(true, false, false, true);
    emit ModifySAFECollateralization(
      collateralType,
      safe,
      src,
      debtDestination,
      0,
      _deltaDebt,
      _lockedCollateral,
      _initialGeneratedDebt.add(_deltaDebt),
      _newGlobalDebt
    );

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, _deltaDebt);
  }

  function test_Emit_ModifySAFECollateralization_LockedColateral(
    int256 _deltaCollateral,
    uint256 _initialSafeLockedCollateral,
    uint256 _initialTokenCollateral
  ) public {
    _assumeHappyPathLockedCollateral(_deltaCollateral, _initialSafeLockedCollateral, _initialTokenCollateral);
    _mockValuesLockedCollateral(_initialSafeLockedCollateral, _initialTokenCollateral);

    vm.expectEmit(true, false, false, true);
    emit ModifySAFECollateralization(
      collateralType,
      safe,
      src,
      debtDestination,
      _deltaCollateral,
      0,
      _initialSafeLockedCollateral.add(_deltaCollateral),
      0,
      0
    );

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, 0);
  }

  function test_Revert_ContractNotEnabled(uint256 _enabled) public {
    vm.assume(_enabled != 1);
    _mockContractEnabled(_enabled);

    vm.expectRevert(bytes('SAFEEngine/contract-not-enabled'));
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, 0);
  }

  function test_RevertcollateralTypeDataAccumulatedRateZero() public {
    _mockCollateralType({
      _collateralType: collateralType,
      _debtAmount: 0,
      _accumulatedRate: 0,
      _safetyPrice: 0,
      _debtCeiling: 0,
      _debtFloor: 0,
      _liquidationPrice: 0
    });

    vm.expectRevert(bytes('SAFEEngine/collateral-type-not-initialized'));

    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, 0);
  }

  function test_Revert_CeilingExceeded(
    int256 _deltaDebt,
    uint256 _globalDebtCeiling,
    uint256 _collateralTypeDebtCeiling
  ) public {
    vm.assume(_deltaDebt > 0);
    vm.assume(_globalDebtCeiling < uint256(_deltaDebt) || _collateralTypeDebtCeiling < uint256(_deltaDebt));

    _mockRevertValues({
      _globalDebtCeiling: _globalDebtCeiling,
      _initialLockedCollateral: 0,
      _initialDebtAmount: 0,
      _collateralTypeDebtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: 0
    });
    vm.expectRevert(bytes('SAFEEngine/ceiling-exceeded'));

    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, 0, _deltaDebt);
  }

  function test_Revert_NotSafe(
    int256 _deltaDebt,
    int256 _deltaCollateral,
    uint256 _globalDebtCeiling,
    uint256 _collateralTypeDebtCeiling
  ) public {
    vm.assume((_deltaDebt > 0 || _deltaCollateral < 0));
    vm.assume(_globalDebtCeiling >= uint256(_deltaDebt) && _collateralTypeDebtCeiling >= uint256(_deltaDebt));

    (uint256 _initialDebt, uint256 _initialLockedCollateral) = _assumeRevertCommon(_deltaDebt, _deltaCollateral);
    vm.assume(_initialDebt.add(_deltaDebt) > _initialLockedCollateral.add(_deltaCollateral));

    _mockRevertValues({
      _globalDebtCeiling: _globalDebtCeiling,
      _initialLockedCollateral: _initialLockedCollateral,
      _initialDebtAmount: _initialDebt,
      _collateralTypeDebtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: 0
    });
    vm.expectRevert(bytes('SAFEEngine/not-safe'));

    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, _deltaDebt);
  }

  function test_Revert_NotAllowedToModifySafe(
    int256 _deltaDebt,
    int256 _deltaCollateral,
    uint256 _globalDebtCeiling,
    uint256 _collateralTypeDebtCeiling
  ) public {
    vm.assume((_deltaDebt > 0 || _deltaCollateral < 0));
    vm.assume(_globalDebtCeiling >= uint256(_deltaDebt) && _collateralTypeDebtCeiling >= uint256(_deltaDebt));
    (uint256 _initialDebt, uint256 _initialLockedCollateral) = _assumeRevertCommon(_deltaDebt, _deltaCollateral);

    vm.assume(_initialDebt.add(_deltaDebt) <= _initialLockedCollateral.add(_deltaCollateral));

    _mockRevertValues({
      _globalDebtCeiling: _globalDebtCeiling,
      _initialLockedCollateral: _initialLockedCollateral,
      _initialDebtAmount: _initialDebt,
      _collateralTypeDebtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: 0
    });
    vm.expectRevert(bytes('SAFEEngine/not-allowed-to-modify-safe'));

    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, _deltaDebt);
  }

  function test_Revert_NotAllowedCollateralSrc(
    int256 _deltaDebt,
    int256 _deltaCollateral,
    uint256 _globalDebtCeiling,
    uint256 _collateralTypeDebtCeiling
  ) public {
    vm.assume(_deltaCollateral > 0);
    vm.assume(_globalDebtCeiling >= uint256(_deltaDebt) && _collateralTypeDebtCeiling >= uint256(_deltaDebt));
    (uint256 _initialDebt, uint256 _initialLockedCollateral) = _assumeRevertCommon(_deltaDebt, _deltaCollateral);

    vm.assume(_initialDebt.add(_deltaDebt) <= _initialLockedCollateral.add(_deltaCollateral));

    _mockRevertValues({
      _globalDebtCeiling: _globalDebtCeiling,
      _initialLockedCollateral: _initialLockedCollateral,
      _initialDebtAmount: _initialDebt,
      _collateralTypeDebtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: 0
    });
    _mockCanModifySafe(src, safe, 0);

    vm.expectRevert(bytes('SAFEEngine/not-allowed-collateral-src'));

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, _deltaDebt);
  }

  function test_Revert_NotAllowedCollateralDst(
    int256 _deltaDebt,
    int256 _deltaCollateral,
    uint256 _globalDebtCeiling,
    uint256 _collateralTypeDebtCeiling
  ) public {
    vm.assume(_deltaDebt < 0);
    vm.assume(_globalDebtCeiling >= uint256(_deltaDebt) && _collateralTypeDebtCeiling >= uint256(_deltaDebt));
    (uint256 _initialDebt, uint256 _initialLockedCollateral) = _assumeRevertCommon(_deltaDebt, _deltaCollateral);
    vm.assume(_initialDebt.add(_deltaDebt) <= _initialLockedCollateral.add(_deltaCollateral));

    _mockRevertValues({
      _globalDebtCeiling: _globalDebtCeiling,
      _initialLockedCollateral: _initialLockedCollateral,
      _initialDebtAmount: _initialDebt,
      _collateralTypeDebtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: 0
    });
    _mockCanModifySafe(debtDestination, safe, 0);

    vm.expectRevert(bytes('SAFEEngine/not-allowed-debt-dst'));

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, _deltaDebt);
  }

  function test_Revert_NoDebt(
    int256 _deltaDebt,
    int256 _deltaCollateral,
    uint256 _globalDebtCeiling,
    uint256 _collateralTypeDebtCeiling,
    uint256 _debtFloor
  ) public {
    vm.assume(_globalDebtCeiling >= uint256(_deltaDebt) && _collateralTypeDebtCeiling >= uint256(_deltaDebt));
    (uint256 _initialDebt, uint256 _initialLockedCollateral) = _assumeRevertCommon(_deltaDebt, _deltaCollateral);
    uint256 _generatedDebt = _initialDebt.add(_deltaDebt);
    vm.assume(
      _generatedDebt != 0 && _generatedDebt < _debtFloor
        && _generatedDebt <= _initialLockedCollateral.add(_deltaCollateral)
    );

    _mockRevertValues({
      _globalDebtCeiling: _globalDebtCeiling,
      _initialLockedCollateral: _initialLockedCollateral,
      _initialDebtAmount: _initialDebt,
      _collateralTypeDebtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: _debtFloor
    });

    vm.expectRevert(bytes('SAFEEngine/dust'));

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, _deltaDebt);
  }

  function test_Revert_AboveDebtLimit(
    int256 _deltaDebt,
    int256 _deltaCollateral,
    uint256 _globalDebtCeiling,
    uint256 _collateralTypeDebtCeiling,
    uint256 safeDebtCeiling
  ) public {
    vm.assume(_deltaDebt > 0);
    vm.assume(_globalDebtCeiling >= uint256(_deltaDebt) && _collateralTypeDebtCeiling >= uint256(_deltaDebt));
    (uint256 _initialDebt, uint256 _initialLockedCollateral) = _assumeRevertCommon(_deltaDebt, _deltaCollateral);
    uint256 _generatedDebt = _initialDebt.add(_deltaDebt);
    vm.assume(_generatedDebt > safeDebtCeiling && _generatedDebt <= _initialLockedCollateral.add(_deltaCollateral));

    _mockRevertValues({
      _globalDebtCeiling: _globalDebtCeiling,
      _initialLockedCollateral: _initialLockedCollateral,
      _initialDebtAmount: _initialDebt,
      _collateralTypeDebtCeiling: _collateralTypeDebtCeiling,
      _debtFloor: 0
    });
    _mockSafeDebtCeiling(safeDebtCeiling);

    vm.expectRevert(bytes('SAFEEngine/above-debt-limit'));

    vm.prank(safe);
    safeEngine.modifySAFECollateralization(collateralType, safe, src, debtDestination, _deltaCollateral, _deltaDebt);
  }
}

contract Unit_SAFEEngine_TransferSafeCollateralAndDebt is Base {
  using Math for uint256;
  using stdStorage for StdStorage;

  event TransferSAFECollateralAndDebt(
    bytes32 indexed _collateralType,
    address indexed _src,
    address indexed _dst,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _srcLockedCollateral,
    uint256 _srcGeneratedDebt,
    uint256 _dstLockedCollateral,
    uint256 _dstGeneratedDebt
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
    _mockSafeData(collateralType, src, _srcInitialLockedCollateral, _srcInitialGeneratedDebt);
    _mockSafeData(collateralType, dst, _dstInitialLockedCollateral, _dstInitialGeneratedDebt);
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

    (uint256 _srcLockedCollateral,) = safeEngine.safes(collateralType, src);
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

    (, uint256 _srcGeneratedDebt) = safeEngine.safes(collateralType, src);
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

    (uint256 _dstLockedCollateral,) = safeEngine.safes(collateralType, dst);
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

    (, uint256 _dstGeneratedDebt) = safeEngine.safes(collateralType, dst);
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
    emit TransferSAFECollateralAndDebt(
      collateralType,
      src,
      dst,
      _deltaCollateral,
      _deltaDebt,
      _srcInitialLockedCollateral.sub(_deltaCollateral),
      _srcInitialGeneratedDebt.sub(_deltaDebt),
      _dstInitialLockedCollateral.add(_deltaCollateral),
      _dstInitialGeneratedDebt.add(_deltaDebt)
    );

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

    vm.expectRevert(ISAFEEngine.NotSAFEAllowed.selector);
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

    vm.expectRevert(bytes('SAFEEngine/not-safe-src'));
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

    vm.expectRevert(bytes('SAFEEngine/not-safe-dst'));
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
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(collateralType).depth(4)
      .checked_write(_debtFloor);

    vm.expectRevert(bytes('SAFEEngine/dust-src'));

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
    stdstore.target(address(safeEngine)).sig(ISAFEEngine.collateralTypes.selector).with_key(collateralType).depth(4)
      .checked_write(_debtFloor);

    vm.expectRevert(bytes('SAFEEngine/dust-dst'));

    vm.prank(account);
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, _deltaCollateral, _deltaDebt);
  }
}

contract Unit_SAFEEngine_ConfiscateSAFECollateralAndDebt is Base {
  using Math for uint256;

  event ConfiscateSAFECollateralAndDebt(
    bytes32 indexed _collateralType,
    address indexed _safe,
    address _collateralCounterparty,
    address _debtCounterparty,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _globalUnbackedDebt
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
    _mockTokenCollateral(collateralType, collateralCounterparty, _tokenCollateral);
    _mockGlobalUnbackedDebt(_debtBalance);
    _mockDebtBalance(debtCounterparty, _debtBalance);
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
      collateralType, safe, collateralCounterparty, debtCounterparty, _deltaCollateral, _deltaDebt
    );

    (uint256 _lockedCollateral,) = safeEngine.safes(collateralType, safe);
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
      collateralType, safe, collateralCounterparty, debtCounterparty, _deltaCollateral, _deltaDebt
    );

    (, uint256 _generatedDebt) = safeEngine.safes(collateralType, safe);
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
      collateralType, safe, collateralCounterparty, debtCounterparty, _deltaCollateral, _deltaDebt
    );

    (uint256 _debtAmount,,,,,) = safeEngine.collateralTypes(collateralType);
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
      collateralType, safe, collateralCounterparty, debtCounterparty, _deltaCollateral, _deltaDebt
    );

    uint256 _newTokenCollateral = safeEngine.tokenCollateral(collateralType, collateralCounterparty);
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
      collateralType, safe, collateralCounterparty, debtCounterparty, _deltaCollateral, _deltaDebt
    );

    uint256 _newDebtBalance = safeEngine.debtBalance(debtCounterparty);
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
      collateralType, safe, collateralCounterparty, debtCounterparty, _deltaCollateral, _deltaDebt
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
      collateralType,
      safe,
      collateralCounterparty,
      debtCounterparty,
      _deltaCollateral,
      _deltaDebt,
      _debtBalance.sub(_accumulatedRate.mul(_deltaDebt))
    );

    safeEngine.confiscateSAFECollateralAndDebt(
      collateralType, safe, collateralCounterparty, debtCounterparty, _deltaCollateral, _deltaDebt
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
  event InitializeCollateralType(bytes32 _collateralType);

  function test_Set_AccummulatedRate(bytes32 _collateralType) public authorized {
    safeEngine.initializeCollateralType(_collateralType);

    (, uint256 _accumulatedRate,,,,) = safeEngine.collateralTypes(_collateralType);
    assertEq(_accumulatedRate, RAY);
  }

  function test_Emit_InitializeCollateralType(bytes32 _collateralType) public authorized {
    expectEmitNoIndex();
    emit InitializeCollateralType(_collateralType);

    safeEngine.initializeCollateralType(_collateralType);
  }

  function test_Revert_NotAuthorized(bytes32 _collateralType) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    safeEngine.initializeCollateralType(_collateralType);
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

    vm.expectRevert(bytes('SAFEEngine/collateral-type-already-exists'));

    safeEngine.initializeCollateralType(_collateralType);
  }
}

contract Unit_SAFEEngine_DisableContract is Base {
  event DisableContract();

  function test_Set_ContractEnabled() public authorized {
    safeEngine.disableContract();

    assertEq(safeEngine.contractEnabled(), 0);
  }

  function test_Emit_DisableContract() public authorized {
    expectEmitNoIndex();
    emit DisableContract();

    safeEngine.disableContract();
  }

  function test_Revert_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    safeEngine.disableContract();
  }
}
