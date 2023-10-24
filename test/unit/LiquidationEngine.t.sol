// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ISAFESaviour} from '@interfaces/external/ISAFESaviour.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ILiquidationEngine, IDisableable, IModifiablePerCollateral} from '@interfaces/ILiquidationEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

import {LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {LiquidationEngineForTest} from '@test/mocks/LiquidationEngineForTest.sol';
import {DummyCollateralAuctionHouse} from '@test/mocks/CollateralAuctionHouseForTest.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {Math, MAX_RAD, RAY, WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  uint256 auctionId = 123_456;

  address deployer = label('deployer');
  address account = label('account');
  address safe = label('safe');
  address mockCollateralAuctionHouse = label('collateralTypeSampleAuctionHouse');
  address mockSaviour = label('saviour');
  address user = label('user');

  bytes32 collateralType = 'collateralTypeSample';

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SAFEEngine'));
  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));

  ILiquidationEngine liquidationEngine;

  // NOTE: calculating _limitAdjustedDebt to mock call is complex, so we use a contract for test
  ICollateralAuctionHouse collateralAuctionHouseForTest =
    ICollateralAuctionHouse(address(new DummyCollateralAuctionHouse()));

  ILiquidationEngine.LiquidationEngineParams liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
    onAuctionSystemCoinLimit: type(uint256).max,
    saviourGasLimit: 10_000_000
  });

  function setUp() public virtual {
    vm.prank(deployer);

    liquidationEngine =
      new LiquidationEngineForTest(address(mockSafeEngine), address(mockAccountingEngine), liquidationEngineParams);
    label(address(liquidationEngine), 'LiquidationEngine');
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }

  function _mockCurrentOnAuctionSystemCoins(uint256 _rad) internal {
    stdstore.target(address(liquidationEngine)).sig(ILiquidationEngine.currentOnAuctionSystemCoins.selector)
      .checked_write(_rad);
  }

  function _mockOnAuctionSystemCoinLimit(uint256 _rad) internal {
    stdstore.target(address(liquidationEngine)).sig(ILiquidationEngine.params.selector).depth(0).checked_write(_rad);
  }

  function _mockSafeSaviours(address _saviour, uint256 _canSave) internal {
    stdstore.target(address(liquidationEngine)).sig(ILiquidationEngine.safeSaviours.selector).with_key(_saviour)
      .checked_write(_canSave);
  }

  function _mockSafeEngineCanModifySafe(address _safe, address _account, bool _canModifySafe) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.canModifySAFE.selector, _safe, _account),
      abi.encode(_canModifySafe)
    );
  }

  function _mockSaveSafe(bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward) internal {
    vm.mockCall(
      address(mockSaviour),
      abi.encodeCall(ISAFESaviour(mockSaviour).saveSAFE, (address(liquidationEngine), '', address(0))),
      abi.encode(_ok, _collateralAdded, _liquidatorReward)
    );
  }

  function _mockCollateralList(bytes32 _cType) internal {
    LiquidationEngineForTest(address(liquidationEngine)).addToCollateralList(_cType);
  }

  function _mockLiquidationEngineCollateralType(
    bytes32 _cType,
    address _collateralAuctionHouse,
    uint256 _liquidationPenalty,
    uint256 _liquidationQuantity
  ) internal {
    /*
      since there is an issue that does not allow to set the collateral auction house using std storage, for now we will use
      modifyParameters for this purpose */
    // https://book.getfoundry.sh/reference/forge-std/std-storage?highlight=std#std-storage
    // https://github.com/foundry-rs/forge-std/issues/101
    LiquidationEngineForTest(address(liquidationEngine)).setCollateralAuctionHouse(_cType, _collateralAuctionHouse);

    // The above code should be implemented this way
    /*
     stdstore.target(address(liquidationEngine)).sig(ILiquidationEngine.cParams.selector).with_key(
      _cType
    ).depth(0).checked_write(_collateralAuctionHouse);
    */

    stdstore.target(address(liquidationEngine)).sig(ILiquidationEngine.cParams.selector).with_key(_cType).depth(1)
      .checked_write(_liquidationPenalty);

    stdstore.target(address(liquidationEngine)).sig(ILiquidationEngine.cParams.selector).with_key(_cType).depth(2)
      .checked_write(_liquidationQuantity);
  }

  function _mockSafeEngineCData(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _lockedAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _liquidationPrice
  ) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeCall(ISAFEEngine(mockSafeEngine).cData, (_cType)),
      abi.encode(_debtAmount, _lockedAmount, _accumulatedRate, _safetyPrice, _liquidationPrice)
    );
  }

  function _mockSafeEngineCParams(bytes32 _cType, uint256 _debtCeiling, uint256 _debtFloor) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeCall(ISAFEEngine(mockSafeEngine).cParams, (_cType)),
      abi.encode(_debtCeiling, _debtFloor)
    );
  }

  function _mockSafeEngineCollateralTypes(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _lockedAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _debtCeiling,
    uint256 _debtFloor,
    uint256 _liquidationPrice
  ) internal {
    _mockSafeEngineCData(_cType, _debtAmount, _lockedAmount, _accumulatedRate, _safetyPrice, _liquidationPrice);
    _mockSafeEngineCParams(_cType, _debtCeiling, _debtFloor);
  }

  function _mockSafeEngineSafes(
    bytes32 _cType,
    address _safe,
    uint256 _lockedCollateral,
    uint256 _generatedDebt
  ) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeCall(ISAFEEngine(mockSafeEngine).safes, (_cType, _safe)),
      abi.encode(_lockedCollateral, _generatedDebt)
    );
  }

  function _mockChosenSafeSaviour(bytes32 _cType, address _safe, address _saviour) internal {
    stdstore.target(address(liquidationEngine)).sig(ILiquidationEngine.chosenSAFESaviour.selector).with_key(_cType)
      .with_key(_safe).checked_write(_saviour);
  }

  function _mockAccountingEnginePushDebtToQueue(uint256 _debt) internal {
    vm.mockCall(
      address(mockAccountingEngine),
      abi.encodeWithSelector(IAccountingEngine.pushDebtToQueue.selector, _debt),
      abi.encode(0)
    );
  }

  function _mockContractEnabled(bool _enabled) internal {
    stdstore.target(address(liquidationEngine)).sig(IDisableable.contractEnabled.selector).checked_write(_enabled);
  }

  function _mockSafeSaviourSaveSafe(
    address _saviour,
    address _sender,
    bytes32 _cType,
    address _safe,
    bool _ok,
    uint256 _collateralAdded,
    uint256 _liquidatorReward
  ) internal {
    vm.mockCall(
      address(_saviour),
      abi.encodeCall(ISAFESaviour(_saviour).saveSAFE, (_sender, _cType, _safe)),
      abi.encode(_ok, _collateralAdded, _liquidatorReward)
    );
  }
}

contract FailorSafeSaviour is ISAFESaviour {
  function saveSAFE(address, bytes32, address) external pure returns (bool, uint256, uint256) {
    revert('Failed to save safe');
  }
}

contract SAFESaviourIncreaseGeneratedDebtOrDecreaseCollateral is ISAFESaviour, Base {
  uint256 generatedDebt;
  uint256 lockedCollateral;
  // true decrease collateral, false increase debt
  bool collateralOrDebt;
  // If true this performs the increase or decrease, if false this saviour does nothing.
  bool performAction;
  // Track if the `saveSAFE` was called
  bool public wasCalled;

  constructor(uint256 _lockedCollateral, uint256 _generatedDebt, bool _collateralOrDebt, bool _performAction) {
    lockedCollateral = _lockedCollateral;
    generatedDebt = _generatedDebt;
    collateralOrDebt = _collateralOrDebt;
    performAction = _performAction;
  }

  function saveSAFE(
    address,
    bytes32 _cType,
    address _safe
  ) external returns (bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward) {
    wasCalled = true;
    if (!performAction) return (true, 0, 0);

    uint256 newLockedCollateral = collateralOrDebt ? lockedCollateral - 1 : lockedCollateral;
    uint256 newGeneratedDebt = collateralOrDebt ? generatedDebt : generatedDebt + 1;
    _mockSafeEngineSafes(_cType, _safe, newLockedCollateral, newGeneratedDebt + 1);

    return (true, 10, 1);
  }
}

contract SAFESaviourCollateralTypeModifier is ISAFESaviour, Base {
  uint256 accumulatedRate;
  uint256 liquidationPrice;
  uint256 generatedDebt;
  uint256 lockedCollateral;

  constructor(uint256 _accumulatedRate, uint256 _liquidationPrice, uint256 _lockedCollateral, uint256 _generatedDebt) {
    accumulatedRate = _accumulatedRate;
    liquidationPrice = _liquidationPrice;
    lockedCollateral = _lockedCollateral;
    generatedDebt = _generatedDebt;
  }

  function saveSAFE(
    address,
    bytes32 _cType,
    address _safe
  ) external returns (bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward) {
    _mockSafeEngineSafes(_cType, _safe, lockedCollateral, generatedDebt);
    _mockSafeEngineCollateralTypes({
      _cType: _cType,
      _debtAmount: 0,
      _lockedAmount: 0,
      _accumulatedRate: accumulatedRate,
      _safetyPrice: 0,
      _debtCeiling: 0,
      _debtFloor: 0,
      _liquidationPrice: liquidationPrice
    });

    return (true, 10, 1);
  }
}

contract Unit_LiquidationEngine_Constructor is Base {
  event AddAuthorization(address _account);
  event ModifyParameters(bytes32 indexed _parameter, bytes32 indexed _cType, bytes _data);

  function test_Set_Authorization() public {
    assertEq(liquidationEngine.authorizedAccounts(deployer), true);
  }

  function test_Set_SafeEngine() public {
    assertEq(address(liquidationEngine.safeEngine()), address(mockSafeEngine));
  }

  function test_Set_AccountingEngine() public {
    assertEq(address(liquidationEngine.accountingEngine()), address(mockAccountingEngine));
  }

  function test_Set_OnAuctionSystemCoinLimit() public {
    assertEq(liquidationEngine.params().onAuctionSystemCoinLimit, type(uint256).max);
  }

  function test_Set_ContractEnabled() public {
    assertEq(liquidationEngine.contractEnabled(), true);
  }

  function test_Emit_AddAuthorization() public {
    vm.expectEmit();
    emit AddAuthorization(deployer);

    vm.prank(deployer);
    new LiquidationEngine(address(mockSafeEngine), address(mockAccountingEngine), liquidationEngineParams);
  }

  function test_Set_LiquidationEngine_Param(ILiquidationEngine.LiquidationEngineParams memory _liquidationEngineParams)
    public
  {
    liquidationEngine =
      new LiquidationEngine(address(mockSafeEngine), address(mockAccountingEngine), _liquidationEngineParams);
    assertEq(abi.encode(liquidationEngine.params()), abi.encode(_liquidationEngineParams));
  }

  function test_Revert_Null_SafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new LiquidationEngine(address(0),  address(mockAccountingEngine), liquidationEngineParams);
  }

  function test_Revert_Null_AccountingEngine() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new LiquidationEngine(address(mockSafeEngine),  address(0), liquidationEngineParams);
  }
}

contract Unit_LiquidationEngine_ModifyParameters is Base {
  function test_ModifyParameters(ILiquidationEngine.LiquidationEngineParams memory _fuzz) public authorized {
    liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(_fuzz.onAuctionSystemCoinLimit));
    liquidationEngine.modifyParameters('saviourGasLimit', abi.encode(_fuzz.saviourGasLimit));

    ILiquidationEngine.LiquidationEngineParams memory _params = liquidationEngine.params();

    assertEq(abi.encode(_fuzz), abi.encode(_params));
  }

  function test_ModifyParameters_PerCollateral(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _fuzz
  ) public authorized mockAsContract(_fuzz.collateralAuctionHouse) {
    _mockCollateralList(_cType);
    vm.assume(_fuzz.collateralAuctionHouse != deployer);
    liquidationEngine.modifyParameters(_cType, 'collateralAuctionHouse', abi.encode(_fuzz.collateralAuctionHouse));
    liquidationEngine.modifyParameters(_cType, 'liquidationPenalty', abi.encode(_fuzz.liquidationPenalty));
    vm.assume(_fuzz.liquidationQuantity <= type(uint256).max / RAY);
    liquidationEngine.modifyParameters(_cType, 'liquidationQuantity', abi.encode(_fuzz.liquidationQuantity));

    ILiquidationEngine.LiquidationEngineCollateralParams memory _params = liquidationEngine.cParams(_cType);

    assertEq(abi.encode(_fuzz), abi.encode(_params));
  }

  function test_Revert_ModifyParameters_LiquidationQuantity(
    bytes32 _cType,
    uint256 _liquidationQuantity
  ) public authorized {
    _mockCollateralList(_cType);

    vm.assume(_liquidationQuantity > type(uint256).max / RAY);
    vm.expectRevert();
    liquidationEngine.modifyParameters(_cType, 'liquidationQuantity', abi.encode(_liquidationQuantity));
  }

  function test_ModifyParameters_AccountingEngine(address _accountingEngine)
    public
    authorized
    mockAsContract(_accountingEngine)
  {
    liquidationEngine.modifyParameters('accountingEngine', abi.encode(_accountingEngine));

    assertEq(_accountingEngine, address(liquidationEngine.accountingEngine()));
  }

  function test_ModifyParameters_CollateralAuctionHouse(
    bytes32 _cType,
    address _previousCAH,
    address _newCAH
  ) public authorized mockAsContract(_newCAH) {
    _mockCollateralList(_cType);

    vm.assume(_newCAH != deployer);
    vm.assume(_previousCAH != deployer);

    LiquidationEngineForTest(address(liquidationEngine)).setCollateralAuctionHouse(_cType, _previousCAH);

    if (_previousCAH != address(0)) {
      vm.expectCall(
        address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.denySAFEModification.selector, _previousCAH)
      );
    }
    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.approveSAFEModification.selector, _newCAH)
    );

    liquidationEngine.modifyParameters(_cType, 'collateralAuctionHouse', abi.encode(_newCAH));
  }

  function test_Revert_ModifyParameters_UnrecognizedParam() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    liquidationEngine.modifyParameters('unrecognizedParam', abi.encode(0));
  }

  function test_Revert_ModifyParameters_PerCollateral_UnrecognizedParam(bytes32 _cType) public authorized {
    _mockCollateralList(_cType);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    liquidationEngine.modifyParameters(_cType, 'unrecognizedParam', abi.encode(0));
  }

  function test_Revert_ModifyParameters_PerCollateral_ContractIsDisabled(bytes32 _cType) public authorized {
    _mockContractEnabled(false);

    vm.expectRevert();
    liquidationEngine.modifyParameters(_cType, 'unrecognizedParam', abi.encode(0));
  }
}

contract Unit_LiquidationEngine_RemoveCoinsFromAuction is Base {
  event UpdateCurrentOnAuctionSystemCoins(uint256 _currentOnAuctionSystemCoins);

  function test_Set_CurrentOnAuctionSystemCoins(
    uint256 _initialCurrentOnAuctionSystemCoins,
    uint256 _rad
  ) public authorized {
    vm.assume(notUnderflow(_initialCurrentOnAuctionSystemCoins, _rad));
    _mockCurrentOnAuctionSystemCoins(_initialCurrentOnAuctionSystemCoins);

    liquidationEngine.removeCoinsFromAuction(_rad);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), _initialCurrentOnAuctionSystemCoins - _rad);
  }

  function test_Emit_UpdateCurrentOnAuctionSystemCoins(
    uint256 _initialCurrentOnAuctionSystemCoins,
    uint256 _rad
  ) public authorized {
    vm.assume(notUnderflow(_initialCurrentOnAuctionSystemCoins, _rad));
    _mockCurrentOnAuctionSystemCoins(_initialCurrentOnAuctionSystemCoins);

    vm.expectEmit();
    emit UpdateCurrentOnAuctionSystemCoins(_initialCurrentOnAuctionSystemCoins - _rad);

    liquidationEngine.removeCoinsFromAuction(_rad);
  }

  function test_Revert_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    liquidationEngine.removeCoinsFromAuction(10);
  }
}

contract Unit_LiquidationEngine_ProtectSafe is Base {
  event ProtectSAFE(bytes32 indexed _cType, address indexed _safe, address _saviour);

  function _mockValues(address _safe, bool _canModifySafe, address _saviour, uint256 _canSave) internal {
    _mockSafeEngineCanModifySafe(_safe, account, _canModifySafe);
    _mockSafeSaviours(_saviour, _canSave);
  }

  function test_Set_ChosenSAFESaviour(bytes32 _cType, address _safe, address _saviour) public {
    _mockValues({_safe: _safe, _canModifySafe: true, _saviour: _saviour, _canSave: 1});
    vm.prank(account);
    liquidationEngine.protectSAFE(_cType, _safe, _saviour);

    assertEq(liquidationEngine.chosenSAFESaviour(_cType, _safe), _saviour);
  }

  function test_Set_ChosenSAFESaviourZeroAddress(bytes32 _cType, address _safe) public {
    _mockSafeEngineCanModifySafe(_safe, account, true);

    vm.prank(account);
    liquidationEngine.protectSAFE(_cType, _safe, address(0));

    assertEq(liquidationEngine.chosenSAFESaviour(_cType, _safe), address(0));
  }

  function test_Call_SAFEEngine_CanModifySafe(bytes32 _cType, address _safe, address _saviour) public {
    _mockValues({_safe: _safe, _canModifySafe: true, _saviour: _saviour, _canSave: 1});
    vm.prank(account);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.canModifySAFE.selector, _safe, account));

    liquidationEngine.protectSAFE(_cType, _safe, _saviour);
  }

  function test_Emit_ProtectSAFE(bytes32 _cType, address _safe, address _saviour) public {
    _mockValues({_safe: _safe, _canModifySafe: true, _saviour: _saviour, _canSave: 1});

    vm.expectEmit(true, false, false, true);
    emit ProtectSAFE(_cType, _safe, _saviour);

    vm.prank(account);
    liquidationEngine.protectSAFE(_cType, _safe, _saviour);
  }

  function test_Revert_CannotModifySafe(bytes32 _cType, address _safe, address _saviour) public {
    _mockValues({_safe: _safe, _canModifySafe: false, _saviour: _saviour, _canSave: 1});

    vm.expectRevert(ILiquidationEngine.LiqEng_CannotModifySAFE.selector);
    vm.prank(account);

    liquidationEngine.protectSAFE(_cType, _safe, _saviour);
  }

  function test_Revert_SaviourNotAuthorized(bytes32 _cType, address _safe, address _saviour) public {
    vm.assume(_saviour != address(0));
    _mockValues({_safe: _safe, _canModifySafe: true, _saviour: _saviour, _canSave: 0});

    vm.expectRevert(ILiquidationEngine.LiqEng_SaviourNotAuthorized.selector);
    vm.prank(account);

    liquidationEngine.protectSAFE(_cType, _safe, _saviour);
  }
}

contract Unit_LiquidationEngine_ConnectSAFESaviour is Base {
  event ConnectSAFESaviour(address _saviour);

  function test_Set_SafeSaviours() public authorized {
    _mockSaveSafe(true, type(uint256).max, type(uint256).max);

    liquidationEngine.connectSAFESaviour(mockSaviour);

    assertEq(liquidationEngine.safeSaviours(mockSaviour), true);
  }

  function test_Emit_ConnectSAFESaviour() public authorized {
    _mockSaveSafe(true, type(uint256).max, type(uint256).max);

    vm.expectEmit();
    emit ConnectSAFESaviour(mockSaviour);

    liquidationEngine.connectSAFESaviour(mockSaviour);
  }

  function test_Call_SaveSAFE() public authorized {
    _mockSaveSafe(true, type(uint256).max, type(uint256).max);

    vm.expectCall(
      address(mockSaviour),
      abi.encodeCall(ISAFESaviour(mockSaviour).saveSAFE, (address(liquidationEngine), '', address(0)))
    );

    liquidationEngine.connectSAFESaviour(mockSaviour);
  }

  function test_Revert_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    liquidationEngine.connectSAFESaviour(mockSaviour);
  }

  function test_Revert_NotOk() public authorized {
    _mockSaveSafe(false, type(uint256).max, type(uint256).max);

    vm.expectRevert(ILiquidationEngine.LiqEng_SaviourNotOk.selector);

    liquidationEngine.connectSAFESaviour(mockSaviour);
  }

  function test_Revert_InvalidAmounts(uint256 _collateralAdded, uint256 _liquidatorReward) public authorized {
    vm.assume(_collateralAdded < type(uint256).max || _liquidatorReward < type(uint256).max);
    _mockSaveSafe(true, _collateralAdded, _liquidatorReward);

    vm.expectRevert(ILiquidationEngine.LiqEng_InvalidAmounts.selector);

    liquidationEngine.connectSAFESaviour(mockSaviour);
  }
}

contract Unit_LiquidationEngine_DisconnectSAFESaviour is Base {
  event DisconnectSAFESaviour(address _saviour);

  function setUp() public virtual override {
    super.setUp();
    _mockSafeSaviours(mockSaviour, 1);
  }

  function test_Set_SafeSaviours() public authorized {
    liquidationEngine.disconnectSAFESaviour(mockSaviour);

    assertEq(liquidationEngine.safeSaviours(mockSaviour), false);
  }

  function test_Emit_DisconnectSAFESaviour() public authorized {
    vm.expectEmit();
    emit DisconnectSAFESaviour(mockSaviour);

    liquidationEngine.disconnectSAFESaviour(mockSaviour);
  }

  function test_Revert_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    liquidationEngine.disconnectSAFESaviour(mockSaviour);
  }
}

contract Unit_LiquidationEngine_GetLimitAdjustedDebtToCover is Base {
  function _assumeHappyPath(
    uint256 _accumulatedRate,
    uint256 _liquidationPenalty,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins
  ) internal pure {
    vm.assume(_accumulatedRate > 0);
    vm.assume(_liquidationPenalty > 0);
    vm.assume(notUnderflow(_onAuctionSystemCoinLimit, _currentOnAuctionSystemCoins));
    vm.assume(notOverflowMul(_liquidationQuantity, _onAuctionSystemCoinLimit - _currentOnAuctionSystemCoins));
  }

  function _mockValues(
    uint256 _accumulatedRate,
    uint256 _safeDebt,
    uint256 _liquidationPenalty,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins
  ) public {
    _mockSafeEngineCData({
      _cType: collateralType,
      _debtAmount: 0,
      _lockedAmount: 0,
      _accumulatedRate: _accumulatedRate,
      _safetyPrice: 0,
      _liquidationPrice: 0
    });
    _mockSafeEngineSafes({_cType: collateralType, _safe: safe, _lockedCollateral: 0, _generatedDebt: _safeDebt});
    _mockLiquidationEngineCollateralType(
      collateralType, mockCollateralAuctionHouse, _liquidationPenalty, _liquidationQuantity
    );
    _mockOnAuctionSystemCoinLimit(_onAuctionSystemCoinLimit);
    _mockCurrentOnAuctionSystemCoins(_currentOnAuctionSystemCoins);
  }

  function test_Return_LimitAdjustedDebtToCover(
    uint256 _accumulatedRate,
    uint256 _safeDebt,
    uint256 _liquidationPenalty,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins
  ) public {
    _assumeHappyPath(
      _accumulatedRate,
      _liquidationPenalty,
      _liquidationQuantity,
      _onAuctionSystemCoinLimit,
      _currentOnAuctionSystemCoins
    );
    _mockValues(
      _accumulatedRate,
      _safeDebt,
      _liquidationPenalty,
      _liquidationQuantity,
      _onAuctionSystemCoinLimit,
      _currentOnAuctionSystemCoins
    );

    uint256 _result = Math.min(
      _safeDebt,
      Math.min(_liquidationQuantity, _onAuctionSystemCoinLimit - _currentOnAuctionSystemCoins) * WAD / _accumulatedRate
        / _liquidationPenalty
    );
    assertEq(liquidationEngine.getLimitAdjustedDebtToCover(collateralType, safe), _result);
  }

  function test_Call_SafeEngineCollateralTypes(
    uint256 _accumulatedRate,
    uint256 _safeDebt,
    uint256 _liquidationPenalty,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins
  ) public {
    _assumeHappyPath(
      _accumulatedRate,
      _liquidationPenalty,
      _liquidationQuantity,
      _onAuctionSystemCoinLimit,
      _currentOnAuctionSystemCoins
    );
    _mockValues(
      _accumulatedRate,
      _safeDebt,
      _liquidationPenalty,
      _liquidationQuantity,
      _onAuctionSystemCoinLimit,
      _currentOnAuctionSystemCoins
    );

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.cData.selector, collateralType));

    liquidationEngine.getLimitAdjustedDebtToCover(collateralType, safe);
  }

  function test_Call_SafeEngineSafes(
    uint256 _accumulatedRate,
    uint256 _safeDebt,
    uint256 _liquidationPenalty,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins
  ) public {
    _assumeHappyPath(
      _accumulatedRate,
      _liquidationPenalty,
      _liquidationQuantity,
      _onAuctionSystemCoinLimit,
      _currentOnAuctionSystemCoins
    );
    _mockValues(
      _accumulatedRate,
      _safeDebt,
      _liquidationPenalty,
      _liquidationQuantity,
      _onAuctionSystemCoinLimit,
      _currentOnAuctionSystemCoins
    );

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector, collateralType, safe));

    liquidationEngine.getLimitAdjustedDebtToCover(collateralType, safe);
  }
}

contract Unit_LiquidationEngine_LiquidateSafe is Base {
  event UpdateCurrentOnAuctionSystemCoins(uint256 _currentOnAuctionSystemCoins);
  event SaveSAFE(bytes32 indexed _cType, address indexed _safe, uint256 _collateralAddedOrDebtRepaid);
  event FailedSAFESave(bytes _failReason);

  struct Liquidation {
    uint256 accumulatedRate;
    uint256 debtFloor;
    uint256 liquidationPrice;
    uint256 safeCollateral;
    uint256 safeDebt;
    uint256 onAuctionSystemCoinLimit;
    uint256 currentOnAuctionSystemCoins;
    uint256 liquidationPenalty;
    uint256 liquidationQuantity;
  }

  event Liquidate(
    bytes32 indexed _cType,
    address indexed _safe,
    uint256 _collateralAmount,
    uint256 _debtAmount,
    uint256 _amountToRaise,
    address _collateralAuctioneer,
    uint256 _auctionId
  );

  function setUp() public virtual override {
    super.setUp();
    LiquidationEngineForTest(address(liquidationEngine)).setAccountingEngine(address(mockAccountingEngine));
    LiquidationEngineForTest(address(liquidationEngine)).setCollateralAuctionHouse(
      collateralType, address(collateralAuctionHouseForTest)
    );
  }

  function _notDusty(
    uint256 _safeDebt,
    uint256 _limitedValue,
    uint256 _liquidationPenalty,
    uint256 _debtFloor,
    uint256 _accumulatedRate
  ) internal pure returns (bool _notDustyBool) {
    vm.assume(notOverflowMul(_limitedValue, WAD));
    uint256 _limitAdjustedDebt = _limitedValue * WAD / _accumulatedRate / _liquidationPenalty;
    // safe debt must be different from the _limitAdjustedDebt value, if not it's pointless to check because it will never be dusty (_limitAdjustedDebt == _safeDebt)
    vm.assume(_safeDebt > _limitAdjustedDebt);
    _notDustyBool = (_safeDebt - _limitAdjustedDebt) * _accumulatedRate >= _debtFloor;
  }

  function _notZeroDivision(
    uint256 _accumulatedRate,
    uint256 _liquidationPenalty
  ) internal pure returns (bool _notZero) {
    _notZero = _accumulatedRate > 0 && _liquidationPenalty > 0;
  }

  function _notSafe(
    uint256 _liquidationPrice,
    uint256 _safeCollateral,
    uint256 _safeDebt,
    uint256 _accumulatedRate
  ) internal pure returns (bool _notSafeBool) {
    if (_liquidationPrice > 0) {
      vm.assume(notOverflowMul(_safeCollateral, _liquidationPrice));
      vm.assume(notOverflowMul(_safeDebt, _accumulatedRate));
      _notSafeBool = _safeCollateral * _liquidationPrice < _safeDebt * _accumulatedRate;
    }
  }

  function _notNullAuction(
    uint256 _limitedValue,
    uint256 _liquidationPenalty,
    uint256 _accumulatedRate
  ) internal pure returns (bool _notNul) {
    vm.assume(notOverflowMul(_limitedValue, WAD));
    _notNul = _limitedValue * WAD / _liquidationPenalty / _accumulatedRate > 0;
  }

  function _notHitLimit(
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins,
    uint256 _debtFloor
  ) internal pure returns (bool _notLimitHit) {
    _notLimitHit = _currentOnAuctionSystemCoins < _onAuctionSystemCoinLimit
      && _onAuctionSystemCoinLimit - _currentOnAuctionSystemCoins >= _debtFloor;
  }

  function _notNullCollateralToSell(
    uint256 _safeDebt,
    uint256 _safeCollateral,
    uint256 _limitedValue,
    uint256 _accumulatedRate,
    uint256 _liquidationPenalty,
    uint256 _currentOnAuctionSystemCoins
  ) internal pure returns (bool _notNull) {
    vm.assume(notOverflowMul(_limitedValue, WAD));
    uint256 _limitAdjustedDebt = _limitedValue * WAD / _accumulatedRate / _liquidationPenalty;
    vm.assume(
      notOverflowMul(_safeCollateral, _limitAdjustedDebt) && notOverflowAdd(_currentOnAuctionSystemCoins, _limitedValue)
    );
    _notNull = _safeCollateral * _limitAdjustedDebt / _safeDebt > 0;
  }

  function _limitByLiquidationQuantity(
    uint256 _safeDebt,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins,
    uint256 _accumulatedRate,
    uint256 _liquidationPenalty
  ) internal pure {
    vm.assume(notOverflowMul(_liquidationQuantity, WAD));
    vm.assume(_onAuctionSystemCoinLimit - _currentOnAuctionSystemCoins > _liquidationQuantity);
    vm.assume(_liquidationQuantity * WAD / _accumulatedRate / _liquidationPenalty < _safeDebt);
  }

  function _limitBySafeDebt(
    uint256 _safeDebt,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins,
    uint256 _accumulatedRate,
    uint256 _liquidationPenalty
  ) internal pure {
    vm.assume(_safeDebt > 0);
    vm.assume(_onAuctionSystemCoinLimit > _currentOnAuctionSystemCoins);
    vm.assume(notOverflowMul(_liquidationQuantity, WAD));
    vm.assume(notOverflowMul((_onAuctionSystemCoinLimit - _currentOnAuctionSystemCoins), WAD));
    vm.assume(_safeDebt <= _liquidationQuantity * WAD / _accumulatedRate / _liquidationPenalty);
    vm.assume(
      _safeDebt
        <= (_onAuctionSystemCoinLimit - _currentOnAuctionSystemCoins) * WAD / _accumulatedRate / _liquidationPenalty
    );
  }

  function _limitByCoins(
    uint256 _safeDebt,
    uint256 _liquidationQuantity,
    uint256 _onAuctionSystemCoinLimit,
    uint256 _currentOnAuctionSystemCoins,
    uint256 _accumulatedRate,
    uint256 _liquidationPenalty
  ) internal pure {
    vm.assume(_onAuctionSystemCoinLimit > _currentOnAuctionSystemCoins);
    uint256 _liquidationAmount = _onAuctionSystemCoinLimit - _currentOnAuctionSystemCoins;
    vm.assume(_liquidationAmount < _liquidationQuantity);
    vm.assume(notOverflowMul(_liquidationAmount, WAD));
    vm.assume(_liquidationAmount * WAD / _accumulatedRate / _liquidationPenalty < _safeDebt);
  }

  function _assumeHappyPathFullLiquidation(Liquidation memory _liquidation) internal pure {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    _limitBySafeDebt(
      _liquidation.safeDebt,
      _liquidation.liquidationQuantity,
      _liquidation.onAuctionSystemCoinLimit,
      _liquidation.currentOnAuctionSystemCoins,
      _liquidation.accumulatedRate,
      _liquidation.liquidationPenalty
    );
    vm.assume(
      _notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notHitLimit(
        _liquidation.onAuctionSystemCoinLimit, _liquidation.currentOnAuctionSystemCoins, _liquidation.debtFloor
      )
    );
    // Not need to call not null auction because we are limiting by safe debt
    // Not needed to call not dusty since it is a full liquidation
    vm.assume(
      _notNullCollateralToSell(
        _liquidation.safeDebt,
        _liquidation.safeCollateral,
        _liquidation.safeDebt,
        _liquidation.accumulatedRate,
        _liquidation.liquidationPenalty,
        _liquidation.currentOnAuctionSystemCoins
      )
    );
  }

  function _assumeHappyPathPartialLiquidationLiqQuantity(Liquidation memory _liquidation) internal pure {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    vm.assume(
      _notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notHitLimit(
        _liquidation.onAuctionSystemCoinLimit, _liquidation.currentOnAuctionSystemCoins, _liquidation.debtFloor
      )
    );
    vm.assume(
      _notNullAuction(_liquidation.liquidationQuantity, _liquidation.liquidationPenalty, _liquidation.accumulatedRate)
    );
    _limitByLiquidationQuantity(
      _liquidation.safeDebt,
      _liquidation.liquidationQuantity,
      _liquidation.onAuctionSystemCoinLimit,
      _liquidation.currentOnAuctionSystemCoins,
      _liquidation.accumulatedRate,
      _liquidation.liquidationPenalty
    );
    vm.assume(
      _notDusty(
        _liquidation.safeDebt,
        _liquidation.liquidationQuantity,
        _liquidation.liquidationPenalty,
        _liquidation.debtFloor,
        _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notNullCollateralToSell(
        _liquidation.safeDebt,
        _liquidation.safeCollateral,
        _liquidation.liquidationQuantity,
        _liquidation.accumulatedRate,
        _liquidation.liquidationPenalty,
        _liquidation.currentOnAuctionSystemCoins
      )
    );
  }

  function _assumeHappyPathPartialLiquidationCoins(Liquidation memory _liquidation) internal pure {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    vm.assume(
      _notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notHitLimit(
        _liquidation.onAuctionSystemCoinLimit, _liquidation.currentOnAuctionSystemCoins, _liquidation.debtFloor
      )
    );
    vm.assume(
      _notNullAuction(
        _liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins,
        _liquidation.liquidationPenalty,
        _liquidation.accumulatedRate
      )
    );
    _limitByCoins(
      _liquidation.safeDebt,
      _liquidation.liquidationQuantity,
      _liquidation.onAuctionSystemCoinLimit,
      _liquidation.currentOnAuctionSystemCoins,
      _liquidation.accumulatedRate,
      _liquidation.liquidationPenalty
    );
    vm.assume(
      _notDusty(
        _liquidation.safeDebt,
        _liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins,
        _liquidation.liquidationPenalty,
        _liquidation.debtFloor,
        _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notNullCollateralToSell(
        _liquidation.safeDebt,
        _liquidation.safeCollateral,
        _liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins,
        _liquidation.accumulatedRate,
        _liquidation.liquidationPenalty,
        _liquidation.currentOnAuctionSystemCoins
      )
    );
  }

  function _mockValues(Liquidation memory _liquidation) internal {
    _mockLiquidationEngineCollateralType(
      collateralType,
      address(collateralAuctionHouseForTest),
      _liquidation.liquidationPenalty,
      _liquidation.liquidationQuantity
    );

    _mockSafeEngineCollateralTypes({
      _cType: collateralType,
      _debtAmount: 0,
      _lockedAmount: 0,
      _accumulatedRate: _liquidation.accumulatedRate,
      _safetyPrice: 0,
      _debtCeiling: 0,
      _debtFloor: _liquidation.debtFloor,
      _liquidationPrice: _liquidation.liquidationPrice
    });

    _mockSafeEngineSafes({
      _cType: collateralType,
      _safe: safe,
      _lockedCollateral: _liquidation.safeCollateral,
      _generatedDebt: _liquidation.safeDebt
    });

    _mockOnAuctionSystemCoinLimit(_liquidation.onAuctionSystemCoinLimit);
    _mockCurrentOnAuctionSystemCoins(_liquidation.currentOnAuctionSystemCoins);
  }

  modifier happyPathFullLiquidation(Liquidation memory _liquidation) {
    _assumeHappyPathFullLiquidation(_liquidation);
    _mockValues(_liquidation);
    _;
  }

  modifier happyPathPartialLiquidationLiquidationQuantity(Liquidation memory _liquidation) {
    _assumeHappyPathPartialLiquidationLiqQuantity(_liquidation);
    _mockValues(_liquidation);
    _;
  }

  modifier happyPathPartialLiquidationCoins(Liquidation memory _liquidation) {
    _assumeHappyPathPartialLiquidationCoins(_liquidation);
    _mockValues(_liquidation);
    _;
  }

  function test_Call_SafeEngine_CData(Liquidation memory _liquidation) public happyPathFullLiquidation(_liquidation) {
    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.cData.selector, collateralType), 1);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_CParams(Liquidation memory _liquidation) public happyPathFullLiquidation(_liquidation) {
    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.cParams.selector, collateralType), 1);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_Safes(Liquidation memory _liquidation) public happyPathFullLiquidation(_liquidation) {
    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector, collateralType, safe), 1);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_ConfiscateSAFECollateralAndDebt(Liquidation memory _liquidation)
    public
    happyPathFullLiquidation(_liquidation)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        ISAFEEngine(mockSafeEngine).confiscateSAFECollateralAndDebt,
        (
          collateralType,
          safe,
          address(liquidationEngine),
          address(mockAccountingEngine),
          -int256(_liquidation.safeCollateral),
          -int256(_liquidation.safeDebt)
        )
      )
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_ConfiscateSAFECollateralAndDebt_PartialLiquidation_LiquidationQuantity(
    Liquidation memory _liquidation
  ) public happyPathPartialLiquidationLiquidationQuantity(_liquidation) {
    uint256 _limitAdjustedDebt =
      _liquidation.liquidationQuantity * WAD / _liquidation.accumulatedRate / _liquidation.liquidationPenalty;
    uint256 _collateralToSell = _liquidation.safeCollateral * _limitAdjustedDebt / _liquidation.safeDebt;

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        ISAFEEngine(mockSafeEngine).confiscateSAFECollateralAndDebt,
        (
          collateralType,
          safe,
          address(liquidationEngine),
          address(mockAccountingEngine),
          -int256(_collateralToSell),
          -int256(_limitAdjustedDebt)
        )
      )
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_ConfiscateSAFECollateralAndDebt_PartialLiquidation_Coins(
    Liquidation memory _liquidation
  ) public happyPathPartialLiquidationCoins(_liquidation) {
    uint256 _limitAdjustedDebt = (_liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins)
      * WAD / _liquidation.accumulatedRate / _liquidation.liquidationPenalty;
    uint256 _collateralToSell = _liquidation.safeCollateral * _limitAdjustedDebt / _liquidation.safeDebt;

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        ISAFEEngine(mockSafeEngine).confiscateSAFECollateralAndDebt,
        (
          collateralType,
          safe,
          address(liquidationEngine),
          address(mockAccountingEngine),
          -int256(_collateralToSell),
          -int256(_limitAdjustedDebt)
        )
      )
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_PushDebtToQueue(Liquidation memory _liquidation)
    public
    happyPathFullLiquidation(_liquidation)
  {
    uint256 _amountToRaise =
      _liquidation.safeDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    _mockAccountingEnginePushDebtToQueue(_amountToRaise);
    uint256 _limitAdjustedDebtMulAccRate = _liquidation.safeDebt * _liquidation.accumulatedRate;
    LiquidationEngineForTest(address(liquidationEngine)).setAccountingEngine(address(mockAccountingEngine));

    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(IAccountingEngine(mockAccountingEngine).pushDebtToQueue, _limitAdjustedDebtMulAccRate)
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_PushDebtToQueue_PartialLiquidation_LiquidationQuantity(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationLiquidationQuantity(_liquidation)
  {
    uint256 _limitAdjustedDebt =
      _liquidation.liquidationQuantity * WAD / _liquidation.accumulatedRate / _liquidation.liquidationPenalty;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    _mockAccountingEnginePushDebtToQueue(_amountToRaise);
    uint256 _limitAdjustedDebtMulAccRate = _limitAdjustedDebt * _liquidation.accumulatedRate;
    LiquidationEngineForTest(address(liquidationEngine)).setAccountingEngine(address(mockAccountingEngine));

    vm.expectCall(
      address(mockAccountingEngine), abi.encodeCall(IAccountingEngine.pushDebtToQueue, _limitAdjustedDebtMulAccRate)
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_SafeEngine_PushDebtToQueue_PartialLiquidation_Coins(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationCoins(_liquidation)
  {
    uint256 _limitAdjustedDebt = (_liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins)
      * WAD / _liquidation.accumulatedRate / _liquidation.liquidationPenalty;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    _mockAccountingEnginePushDebtToQueue(_amountToRaise);
    uint256 _limitAdjustedDebtMulAccRate = _limitAdjustedDebt * _liquidation.accumulatedRate;
    LiquidationEngineForTest(address(liquidationEngine)).setAccountingEngine(address(mockAccountingEngine));

    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(IAccountingEngine(mockAccountingEngine).pushDebtToQueue, _limitAdjustedDebtMulAccRate)
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_CollateralAuctionHouse_StartAuction(Liquidation memory _liquidation)
    public
    happyPathFullLiquidation(_liquidation)
  {
    uint256 _amountToRaise =
      _liquidation.safeDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;

    vm.expectCall(
      address(collateralAuctionHouseForTest),
      abi.encodeCall(
        ICollateralAuctionHouse.startAuction,
        (safe, address(mockAccountingEngine), _amountToRaise, _liquidation.safeCollateral)
      )
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_CollateralAuctionHouse_StartAuction_PartialLiquidation_LiquidationQuantity(
    Liquidation memory _liquidation
  ) public happyPathPartialLiquidationLiquidationQuantity(_liquidation) {
    uint256 _limitAdjustedDebt =
      _liquidation.liquidationQuantity * WAD / _liquidation.accumulatedRate / _liquidation.liquidationPenalty;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    uint256 _collateralToSell = _liquidation.safeCollateral * _limitAdjustedDebt / _liquidation.safeDebt;

    vm.expectCall(
      address(collateralAuctionHouseForTest),
      abi.encodeCall(
        ICollateralAuctionHouse.startAuction, (safe, address(mockAccountingEngine), _amountToRaise, _collateralToSell)
      )
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Call_CollateralAuctionHouse_StartAuction_PartialLiquidation_Coins(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationCoins(_liquidation)
  {
    uint256 _limitAdjustedDebt = (_liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins)
      * WAD / _liquidation.accumulatedRate / _liquidation.liquidationPenalty;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    uint256 _collateralToSell = _liquidation.safeCollateral * _limitAdjustedDebt / _liquidation.safeDebt;

    vm.expectCall(
      address(collateralAuctionHouseForTest),
      abi.encodeCall(
        ICollateralAuctionHouse.startAuction, (safe, address(mockAccountingEngine), _amountToRaise, _collateralToSell)
      )
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Set_CurrentOnAuctionSystemCoins(Liquidation memory _liquidation)
    public
    happyPathFullLiquidation(_liquidation)
  {
    uint256 _amountToRaise =
      _liquidation.safeDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    liquidationEngine.liquidateSAFE(collateralType, safe);

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), _liquidation.currentOnAuctionSystemCoins + _amountToRaise);
  }

  function test_Set_CurrentOnAuctionSystemCoins_Partial_LiquidationQuantity(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationLiquidationQuantity(_liquidation)
  {
    uint256 _limitAdjustedDebt =
      _liquidation.liquidationQuantity * WAD / _liquidation.liquidationPenalty / _liquidation.accumulatedRate;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    liquidationEngine.liquidateSAFE(collateralType, safe);

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), _liquidation.currentOnAuctionSystemCoins + _amountToRaise);
  }

  function test_Set_CurrentOnAuctionSystemCoins_Partial_Coins(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationCoins(_liquidation)
  {
    uint256 _limitAdjustedDebt = (_liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins)
      * WAD / _liquidation.liquidationPenalty / _liquidation.accumulatedRate;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    liquidationEngine.liquidateSAFE(collateralType, safe);

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), _liquidation.currentOnAuctionSystemCoins + _amountToRaise);
  }

  function test_Emit_UpdateCurrentOnAuctionSystemCoins(Liquidation memory _liquidation)
    public
    happyPathFullLiquidation(_liquidation)
  {
    uint256 _amountToRaise =
      _liquidation.safeDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    vm.expectEmit();
    emit UpdateCurrentOnAuctionSystemCoins(_liquidation.currentOnAuctionSystemCoins + _amountToRaise);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Emit_UpdateCurrentOnAuctionSystemCoins_PartialLiquidation_LiquidationQuantity(
    Liquidation memory _liquidation
  ) public happyPathPartialLiquidationLiquidationQuantity(_liquidation) {
    uint256 _limitAdjustedDebt =
      _liquidation.liquidationQuantity * WAD / _liquidation.liquidationPenalty / _liquidation.accumulatedRate;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    vm.expectEmit();
    emit UpdateCurrentOnAuctionSystemCoins(_liquidation.currentOnAuctionSystemCoins + _amountToRaise);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Emit_UpdateCurrentOnAuctionSystemCoins_PartialLiquidation_Coins(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationCoins(_liquidation)
  {
    uint256 _limitAdjustedDebt = (_liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins)
      * WAD / _liquidation.liquidationPenalty / _liquidation.accumulatedRate;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    vm.expectEmit();
    emit UpdateCurrentOnAuctionSystemCoins(_liquidation.currentOnAuctionSystemCoins + _amountToRaise);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Emit_Liquidate(Liquidation memory _liquidation) public happyPathFullLiquidation(_liquidation) {
    uint256 _amountToRaise =
      _liquidation.safeDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    vm.expectEmit();
    emit Liquidate(
      collateralType,
      safe,
      _liquidation.safeCollateral,
      _liquidation.safeDebt,
      _amountToRaise,
      address(collateralAuctionHouseForTest),
      auctionId
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Emit_Liquidate_PartialLiquidation_LiquidationQuantity(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationLiquidationQuantity(_liquidation)
  {
    uint256 _limitAdjustedDebt =
      _liquidation.liquidationQuantity * WAD / _liquidation.liquidationPenalty / _liquidation.accumulatedRate;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    uint256 _collateralToSell = _liquidation.safeCollateral * _limitAdjustedDebt / _liquidation.safeDebt;
    vm.expectEmit();
    emit Liquidate(
      collateralType,
      safe,
      _collateralToSell,
      _limitAdjustedDebt,
      _amountToRaise,
      address(collateralAuctionHouseForTest),
      auctionId
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Emit_Liquidate_PartialLiquidation_Coins(Liquidation memory _liquidation)
    public
    happyPathPartialLiquidationCoins(_liquidation)
  {
    uint256 _limitAdjustedDebt = (_liquidation.onAuctionSystemCoinLimit - _liquidation.currentOnAuctionSystemCoins)
      * WAD / _liquidation.liquidationPenalty / _liquidation.accumulatedRate;
    uint256 _amountToRaise = _limitAdjustedDebt * _liquidation.accumulatedRate * _liquidation.liquidationPenalty / WAD;
    uint256 _collateralToSell = _liquidation.safeCollateral * _limitAdjustedDebt / _liquidation.safeDebt;
    vm.expectEmit();
    emit Liquidate(
      collateralType,
      safe,
      _collateralToSell,
      _limitAdjustedDebt,
      _amountToRaise,
      address(collateralAuctionHouseForTest),
      auctionId
    );

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_ContractIsDisabled() public {
    // We don't care about any of these values just mocking for call to work when calling safe engine
    _mockValues(Liquidation(0, 0, 0, 0, 0, 0, 0, 0, 0));
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_SafeNotSafe(Liquidation memory _liquidation) public {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    vm.assume(
      !_notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );

    _mockValues(
      Liquidation({
        accumulatedRate: _liquidation.accumulatedRate,
        debtFloor: 0,
        liquidationPrice: _liquidation.liquidationPrice,
        safeCollateral: _liquidation.safeCollateral,
        safeDebt: _liquidation.safeDebt,
        onAuctionSystemCoinLimit: 0,
        currentOnAuctionSystemCoins: 0,
        liquidationPenalty: _liquidation.liquidationPenalty,
        liquidationQuantity: 0
      })
    );

    vm.expectRevert(ILiquidationEngine.LiqEng_SAFENotUnsafe.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_LiquidationLimitHit(Liquidation memory _liquidation) public {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    _limitBySafeDebt(
      _liquidation.safeDebt,
      _liquidation.liquidationQuantity,
      _liquidation.onAuctionSystemCoinLimit,
      _liquidation.currentOnAuctionSystemCoins,
      _liquidation.accumulatedRate,
      _liquidation.liquidationPenalty
    );
    vm.assume(
      _notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );
    vm.assume(
      !_notHitLimit(
        _liquidation.onAuctionSystemCoinLimit, _liquidation.currentOnAuctionSystemCoins, _liquidation.debtFloor
      )
    );

    _mockValues(
      Liquidation({
        accumulatedRate: _liquidation.accumulatedRate,
        debtFloor: _liquidation.debtFloor,
        liquidationPrice: _liquidation.liquidationPrice,
        safeCollateral: _liquidation.safeCollateral,
        safeDebt: _liquidation.safeDebt,
        onAuctionSystemCoinLimit: _liquidation.onAuctionSystemCoinLimit,
        currentOnAuctionSystemCoins: _liquidation.currentOnAuctionSystemCoins,
        liquidationPenalty: _liquidation.liquidationPenalty,
        liquidationQuantity: _liquidation.liquidationQuantity
      })
    );

    vm.expectRevert(ILiquidationEngine.LiqEng_LiquidationLimitHit.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_NullAuction(Liquidation memory _liquidation) public {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    vm.assume(
      _notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notHitLimit(
        _liquidation.onAuctionSystemCoinLimit, _liquidation.currentOnAuctionSystemCoins, _liquidation.debtFloor
      )
    );
    _limitByLiquidationQuantity(
      _liquidation.safeDebt,
      _liquidation.liquidationQuantity,
      _liquidation.onAuctionSystemCoinLimit,
      _liquidation.currentOnAuctionSystemCoins,
      _liquidation.accumulatedRate,
      _liquidation.liquidationPenalty
    );
    vm.assume(
      !_notNullAuction(_liquidation.liquidationQuantity, _liquidation.liquidationPenalty, _liquidation.accumulatedRate)
    );

    _mockValues(
      Liquidation({
        accumulatedRate: _liquidation.accumulatedRate,
        debtFloor: _liquidation.debtFloor,
        liquidationPrice: _liquidation.liquidationPrice,
        safeCollateral: _liquidation.safeCollateral,
        safeDebt: _liquidation.safeDebt,
        onAuctionSystemCoinLimit: _liquidation.onAuctionSystemCoinLimit,
        currentOnAuctionSystemCoins: _liquidation.currentOnAuctionSystemCoins,
        liquidationPenalty: _liquidation.liquidationPenalty,
        liquidationQuantity: _liquidation.liquidationQuantity
      })
    );

    vm.expectRevert(ILiquidationEngine.LiqEng_NullAuction.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_NullCollateralToSell(Liquidation memory _liquidation) public {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    vm.assume(
      _notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notHitLimit(
        _liquidation.onAuctionSystemCoinLimit, _liquidation.currentOnAuctionSystemCoins, _liquidation.debtFloor
      )
    );
    vm.assume(
      _notNullAuction(_liquidation.liquidationQuantity, _liquidation.liquidationPenalty, _liquidation.accumulatedRate)
    );
    _limitByLiquidationQuantity(
      _liquidation.safeDebt,
      _liquidation.liquidationQuantity,
      _liquidation.onAuctionSystemCoinLimit,
      _liquidation.currentOnAuctionSystemCoins,
      _liquidation.accumulatedRate,
      _liquidation.liquidationPenalty
    );
    vm.assume(
      !_notNullCollateralToSell(
        _liquidation.safeDebt,
        _liquidation.safeCollateral,
        _liquidation.liquidationQuantity,
        _liquidation.accumulatedRate,
        _liquidation.liquidationPenalty,
        _liquidation.currentOnAuctionSystemCoins
      )
    );

    _mockValues(
      Liquidation(
        _liquidation.accumulatedRate,
        _liquidation.debtFloor,
        _liquidation.liquidationPrice,
        _liquidation.safeCollateral,
        _liquidation.safeDebt,
        _liquidation.onAuctionSystemCoinLimit,
        _liquidation.currentOnAuctionSystemCoins,
        _liquidation.liquidationPenalty,
        _liquidation.liquidationQuantity
      )
    );

    vm.expectRevert(ILiquidationEngine.LiqEng_NullCollateralToSell.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_DustySafe_LiquidationQuantity(Liquidation memory _liquidation) public {
    vm.assume(_notZeroDivision(_liquidation.accumulatedRate, _liquidation.liquidationPenalty));
    vm.assume(
      _notSafe(
        _liquidation.liquidationPrice, _liquidation.safeCollateral, _liquidation.safeDebt, _liquidation.accumulatedRate
      )
    );
    vm.assume(
      _notNullAuction(_liquidation.liquidationQuantity, _liquidation.liquidationPenalty, _liquidation.accumulatedRate)
    );
    vm.assume(
      _notNullCollateralToSell(
        _liquidation.safeDebt,
        _liquidation.safeCollateral,
        _liquidation.liquidationQuantity,
        _liquidation.accumulatedRate,
        _liquidation.liquidationPenalty,
        _liquidation.currentOnAuctionSystemCoins
      )
    );
    // Making it dusty
    vm.assume(
      !_notDusty(
        _liquidation.safeDebt,
        _liquidation.liquidationQuantity,
        _liquidation.liquidationPenalty,
        _liquidation.debtFloor,
        _liquidation.accumulatedRate
      )
    );

    _mockValues(
      Liquidation({
        accumulatedRate: _liquidation.accumulatedRate,
        debtFloor: _liquidation.debtFloor,
        liquidationPrice: _liquidation.liquidationPrice,
        safeCollateral: _liquidation.safeCollateral,
        safeDebt: _liquidation.safeDebt,
        onAuctionSystemCoinLimit: type(uint256).max,
        currentOnAuctionSystemCoins: 0,
        liquidationPenalty: _liquidation.liquidationPenalty,
        liquidationQuantity: _liquidation.liquidationQuantity
      })
    );

    vm.expectRevert(ILiquidationEngine.LiqEng_DustySAFE.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_CollateralOverflow() public {
    uint256 _safeCollateral = (2 ** 255) + 1;
    uint256 _accumulatedRate = _safeCollateral + 1;
    uint256 _onAuctionSystemCoinLimit = _accumulatedRate / (WAD - 1);
    uint256 _liquidationQuantity = _accumulatedRate / (WAD - 1);

    _mockValues(
      Liquidation({
        accumulatedRate: _accumulatedRate,
        debtFloor: 1,
        liquidationPrice: 1,
        safeCollateral: _safeCollateral,
        safeDebt: 1,
        onAuctionSystemCoinLimit: _onAuctionSystemCoinLimit,
        currentOnAuctionSystemCoins: 1,
        liquidationPenalty: 1,
        liquidationQuantity: _liquidationQuantity
      })
    );

    vm.expectRevert(Math.IntOverflow.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Revert_DebtOverflow() public {
    uint256 _safeCollateral = 1;
    uint256 _safeDebt = (2 ** 255) + 1;
    uint256 _accumulatedRate = 1;
    uint256 _onAuctionSystemCoinLimit = (2 ** 255) / (WAD - 1);
    uint256 _liquidationQuantity = (2 ** 255) + 1;

    _mockValues(
      Liquidation({
        accumulatedRate: _accumulatedRate,
        debtFloor: 1,
        liquidationPrice: 1,
        safeCollateral: _safeCollateral,
        safeDebt: _safeDebt,
        onAuctionSystemCoinLimit: _onAuctionSystemCoinLimit,
        currentOnAuctionSystemCoins: 1,
        liquidationPenalty: 1,
        liquidationQuantity: _liquidationQuantity
      })
    );

    vm.expectRevert(Math.IntOverflow.selector);

    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function _mockSaveSafeValues(uint256 _collateralAddedOrDebtRepaid) internal {
    _mockChosenSafeSaviour(collateralType, safe, mockSaviour);
    _mockSafeSaviours(mockSaviour, 1);
    _mockSafeSaviourSaveSafe(mockSaviour, user, collateralType, safe, true, _collateralAddedOrDebtRepaid, 10);
  }

  function test_Call_SaveSAFE(
    Liquidation memory _liquidation,
    uint256 _collateralAddedOrDebtRepaid
  ) public happyPathFullLiquidation(_liquidation) {
    _mockSaveSafeValues(_collateralAddedOrDebtRepaid);

    vm.expectCall(
      address(mockSaviour), abi.encodeCall(ISAFESaviour(mockSaviour).saveSAFE, (user, collateralType, safe))
    );

    vm.prank(user);
    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Emit_SaveSAFE(
    Liquidation memory _liquidation,
    uint256 _collateralAddedOrDebtRepaid
  ) public happyPathFullLiquidation(_liquidation) {
    vm.assume(_collateralAddedOrDebtRepaid > 0);

    _mockSaveSafeValues(_collateralAddedOrDebtRepaid);

    vm.expectEmit(true, false, false, true);
    emit SaveSAFE(collateralType, safe, _collateralAddedOrDebtRepaid);

    vm.prank(user);
    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_Emit_FailedSAFESave(Liquidation memory _liquidation) public happyPathFullLiquidation(_liquidation) {
    ISAFESaviour _testSaveSaviour = new FailorSafeSaviour();
    _mockChosenSafeSaviour(collateralType, safe, address(_testSaveSaviour));
    _mockSafeSaviours(address(_testSaveSaviour), 1);

    bytes memory _reason = abi.encodeWithSignature('Error(string)', 'Failed to save safe');
    vm.expectEmit();
    emit FailedSAFESave(_reason);

    vm.prank(user);
    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_InternalRevert_InvalidSaviourOperation_IncreaseGeneratedDebt(
    Liquidation memory _liquidation,
    bool _attemptIncrease
  ) public happyPathFullLiquidation(_liquidation) {
    vm.assume(_liquidation.safeDebt < type(uint256).max);

    ISAFESaviour _testSaveSaviour =
    new SAFESaviourIncreaseGeneratedDebtOrDecreaseCollateral(_liquidation.safeCollateral, _liquidation.safeDebt, false, _attemptIncrease);
    _mockChosenSafeSaviour(collateralType, safe, address(_testSaveSaviour));
    _mockSafeSaviours(address(_testSaveSaviour), 1);
    _mockSafeEngineSafes(collateralType, safe, _liquidation.safeCollateral, _liquidation.safeDebt);

    vm.prank(user);
    liquidationEngine.liquidateSAFE(collateralType, safe);

    // Test that if an increase was attempted the state was reverted to reflect it never happening
    // if no increase was attempted the call will succeed.
    assertEq(
      _attemptIncrease, !SAFESaviourIncreaseGeneratedDebtOrDecreaseCollateral(address(_testSaveSaviour)).wasCalled()
    );
  }

  function test_InternalRevert_InvalidSaviourOperation_DecreaseCollateral(
    Liquidation memory _liquidation,
    bool _attemptDecrease
  ) public happyPathFullLiquidation(_liquidation) {
    ISAFESaviour _testSaveSaviour =
    new SAFESaviourIncreaseGeneratedDebtOrDecreaseCollateral(_liquidation.safeCollateral, _liquidation.safeDebt, true, _attemptDecrease);
    _mockChosenSafeSaviour(collateralType, safe, address(_testSaveSaviour));
    _mockSafeSaviours(address(_testSaveSaviour), 1);

    vm.prank(user);
    liquidationEngine.liquidateSAFE(collateralType, safe);

    // Test that if an decrease was attempted the state was reverted to reflect it never happening
    // if no decrease was attempted the call will succeed.
    assertEq(
      _attemptDecrease, !SAFESaviourIncreaseGeneratedDebtOrDecreaseCollateral(address(_testSaveSaviour)).wasCalled()
    );
  }

  function test_NotRevert_NewLiquidationPriceIsZero(Liquidation memory _liquidation)
    public
    happyPathFullLiquidation(_liquidation)
  {
    ISAFESaviour _testSaveSaviour =
    new SAFESaviourCollateralTypeModifier(_liquidation.accumulatedRate, 0, _liquidation.safeCollateral, _liquidation.safeDebt);
    _mockChosenSafeSaviour(collateralType, safe, address(_testSaveSaviour));
    _mockSafeSaviours(address(_testSaveSaviour), 1);

    vm.prank(user);
    liquidationEngine.liquidateSAFE(collateralType, safe);
  }

  function test_NotRevert_NewSafeIsNotUnsafe(
    Liquidation memory _initialLiquidation,
    uint256 _newAccumulatedRate,
    uint256 _newLiquidationPrice,
    uint256 _newSafeCollateral,
    uint256 _newSafeDebt
  ) public happyPathFullLiquidation(_initialLiquidation) {
    vm.assume(notOverflowMul(_newSafeCollateral, _newLiquidationPrice));
    vm.assume(notOverflowMul(_newSafeDebt, _newAccumulatedRate));
    vm.assume(_newSafeDebt < _initialLiquidation.safeDebt);
    vm.assume(_newSafeCollateral > _initialLiquidation.safeCollateral);

    vm.assume(!_notSafe(_newLiquidationPrice, _newSafeCollateral, _newSafeDebt, _newAccumulatedRate));

    ISAFESaviour _testSaveSaviour =
      new SAFESaviourCollateralTypeModifier(_newAccumulatedRate, _newLiquidationPrice, _newSafeCollateral, _newSafeDebt);
    _mockChosenSafeSaviour(collateralType, safe, address(_testSaveSaviour));
    _mockSafeSaviours(address(_testSaveSaviour), 1);

    vm.prank(user);
    liquidationEngine.liquidateSAFE(collateralType, safe);
  }
}

contract Unit_LiquidationEngine_InitializeCollateralType is Base {
  event AddAuthorization(address _account);

  modifier happyPath(ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams) {
    _assumeHappyPath(_liqEngineCParams);
    _mockValues(_liqEngineCParams);
    _;
  }

  function _assumeHappyPath(ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams)
    internal
    view
  {
    vm.assume(_liqEngineCParams.collateralAuctionHouse != deployer);
    vm.assume(_liqEngineCParams.liquidationQuantity <= MAX_RAD);
  }

  function _mockValues(ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams) internal {}

  function test_Set_CParams(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public authorized happyPath(_liqEngineCParams) mockAsContract(_liqEngineCParams.collateralAuctionHouse) {
    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));

    assertEq(abi.encode(liquidationEngine.cParams(_cType)), abi.encode(_liqEngineCParams));
  }

  function test_Call_SAFEEngine_ApproveSAFEModification(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public authorized happyPath(_liqEngineCParams) mockAsContract(_liqEngineCParams.collateralAuctionHouse) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.approveSAFEModification, (_liqEngineCParams.collateralAuctionHouse))
    );

    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));
  }

  function test_Emit_AddAuthorization(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public authorized happyPath(_liqEngineCParams) mockAsContract(_liqEngineCParams.collateralAuctionHouse) {
    vm.expectEmit();
    emit AddAuthorization(_liqEngineCParams.collateralAuctionHouse);

    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));
  }

  function test_Revert_CollateralAuctionHouse_NullAddress(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public authorized {
    _liqEngineCParams.collateralAuctionHouse = address(0);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));
  }

  function test_Revert_LiquidationQuantity_NotLesserOrEqualThan(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public authorized mockAsContract(_liqEngineCParams.collateralAuctionHouse) {
    vm.assume(_liqEngineCParams.collateralAuctionHouse != deployer);
    vm.assume(_liqEngineCParams.liquidationQuantity > MAX_RAD);

    vm.expectRevert(
      abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _liqEngineCParams.liquidationQuantity, MAX_RAD)
    );

    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));
  }

  function test_Revert_NotAuthorized(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));
  }

  function test_Revert_CollateralTypeAlreadyInitialized(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public authorized {
    _mockCollateralList(_cType);

    vm.expectRevert(IModifiablePerCollateral.CollateralTypeAlreadyInitialized.selector);

    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));
  }

  function test_Revert_ContractIsDisabled(
    bytes32 _cType,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _liqEngineCParams
  ) public authorized {
    _mockCollateralList(_cType);
    _mockContractEnabled(false);

    vm.expectRevert();
    liquidationEngine.initializeCollateralType(_cType, abi.encode(_liqEngineCParams));
  }
}
