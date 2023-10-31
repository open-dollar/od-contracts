// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

import {StabilityFeeTreasuryForTest} from '@test/mocks/StabilityFeeTreasuryForTest.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

import {Math, RAY, WAD, HOUR} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');
  address mockExtraSurplusReceiver = label('surplusReceiver');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('mockSafeEngine'));
  ICoinJoin mockCoinJoin = ICoinJoin(mockContract('coinJoin'));
  ISystemCoin mockSystemCoin = ISystemCoin(mockContract('systemCoin'));

  StabilityFeeTreasuryForTest stabilityFeeTreasury;

  IStabilityFeeTreasury.StabilityFeeTreasuryParams stabilityFeeTreasuryParams = IStabilityFeeTreasury
    .StabilityFeeTreasuryParams({treasuryCapacity: 0, pullFundsMinThreshold: 0, surplusTransferDelay: 0});

  function _mockCoinJoinSystemCoin(address _systemCoin) internal {
    vm.mockCall(address(mockCoinJoin), abi.encodeWithSelector(ICoinJoin.systemCoin.selector), abi.encode(_systemCoin));
  }

  function _mockSystemCoinApprove(address _account, uint256 _amount, bool _success) internal {
    vm.mockCall(
      address(mockSystemCoin), abi.encodeWithSelector(IERC20.approve.selector, _account, _amount), abi.encode(_success)
    );
  }

  function _mockSystemCoinBalanceOf(uint256 _balance) internal {
    vm.mockCall(
      address(mockSystemCoin),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(stabilityFeeTreasury)),
      abi.encode(_balance)
    );
  }

  function _mockSafeEngineCoinBalance(uint256 _balance) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(stabilityFeeTreasury)),
      abi.encode(_balance)
    );
  }

  function _mockSafeEngineDebtBalance(uint256 _balance) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.debtBalance.selector, address(stabilityFeeTreasury)),
      abi.encode(_balance)
    );
  }

  function _mockContractEnabled(bool _enabled) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IDisableable.contractEnabled.selector).checked_write(_enabled);
  }

  function _mockTotalAllowance(address _account, uint256 _rad) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.allowance.selector).with_key(_account)
      .depth(0).checked_write(_rad);
  }

  function _mockPerHourAllowance(address _account, uint256 _rad) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.allowance.selector).with_key(_account)
      .depth(1).checked_write(_rad);
  }

  function _mockPulledPerHour(address _account, uint256 _blockHour, uint256 _value) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.pulledPerHour.selector).with_key(_account)
      .with_key(_blockHour).checked_write(_value);
  }

  function _mockLatestSurplusTransferTime(uint256 _latestSurplusTransferTime) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.latestSurplusTransferTime.selector)
      .checked_write(_latestSurplusTransferTime);
  }

  // params
  function _mockTreasuryCapacity(uint256 _capacity) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(0).checked_write(
      _capacity
    );
  }

  function _mockPullFundsMinThreshold(uint256 _value) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(1).checked_write(
      _value
    );
  }

  function _mockSurplusTransferDelay(uint256 _surplusTransferDelay) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(2).checked_write(
      _surplusTransferDelay
    );
  }

  function setUp() public virtual {
    vm.startPrank(deployer);

    _mockCoinJoinSystemCoin(address(mockSystemCoin));
    _mockSystemCoinApprove(address(mockCoinJoin), type(uint256).max, true);

    stabilityFeeTreasury =
    new StabilityFeeTreasuryForTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin), stabilityFeeTreasuryParams);
    label(address(stabilityFeeTreasury), 'StabilityFeeTreasury');

    stabilityFeeTreasury.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
  }
}

contract Unit_StabilityFeeTreasury_Constructor is Base {
  event AddAuthorization(address _account);

  function test_Emit_AddAuthorization() public {
    vm.expectEmit();
    emit AddAuthorization(user);

    vm.prank(user);
    new StabilityFeeTreasuryForTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin), stabilityFeeTreasuryParams);
  }

  function test_Set_ContractEnabled() public {
    assertEq(stabilityFeeTreasury.contractEnabled(), true);
  }

  function test_Set_SafeEngine() public {
    assertEq(address(stabilityFeeTreasury.safeEngine()), address(mockSafeEngine));
  }

  function test_Set_CoinJoin() public {
    assertEq(address(stabilityFeeTreasury.coinJoin()), address(mockCoinJoin));
  }

  function test_Set_ExtraSurplusReceiver() public {
    assertEq(address(stabilityFeeTreasury.extraSurplusReceiver()), mockExtraSurplusReceiver);
  }

  function test_Set_SystemCoin() public {
    assertEq(address(stabilityFeeTreasury.systemCoin()), address(mockSystemCoin));
  }

  function test_Set_LatestSurplusTransferTime() public {
    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
  }

  function test_Set_StabilityFeeTreasury_Params(
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _stabilityFeeTreasuryParams
  ) public {
    stabilityFeeTreasury =
    new StabilityFeeTreasuryForTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin), _stabilityFeeTreasuryParams);

    assertEq(abi.encode(stabilityFeeTreasury.params()), abi.encode(_stabilityFeeTreasuryParams));
  }

  function test_Call_SystemCoin_Approve() public {
    vm.expectCall(
      address(mockSystemCoin), abi.encodeWithSelector(IERC20.approve.selector, address(mockCoinJoin), type(uint256).max)
    );

    new StabilityFeeTreasuryForTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin), stabilityFeeTreasuryParams);
  }

  function test_Revert_NullAddress_SafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new StabilityFeeTreasuryForTest(address(0), mockExtraSurplusReceiver, address(mockCoinJoin), stabilityFeeTreasuryParams);
  }

  function test_Revert_NullAddress_SystemCoin() public {
    _mockCoinJoinSystemCoin(address(0));

    vm.expectRevert(Assertions.NullAddress.selector);

    new StabilityFeeTreasuryForTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin), stabilityFeeTreasuryParams);
  }

  function test_Revert_NullAddress_ExtraSurplusReceiver() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new StabilityFeeTreasuryForTest(address(mockSafeEngine), address(0), address(mockCoinJoin), stabilityFeeTreasuryParams);
  }
}

contract Unit_StabilityFeeTreasury_ModifyParameters is Base {
  function test_ModifyParameters(IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _fuzz) public authorized {
    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(_fuzz.treasuryCapacity));
    stabilityFeeTreasury.modifyParameters('pullFundsMinThreshold', abi.encode(_fuzz.pullFundsMinThreshold));
    stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(_fuzz.surplusTransferDelay));

    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _params = stabilityFeeTreasury.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_ModifyParameters_ExtraSurplusReceiver(address _extraSurplusReceiver) public authorized {
    vm.assume(_extraSurplusReceiver != address(0));
    vm.assume(_extraSurplusReceiver != address(stabilityFeeTreasury));

    stabilityFeeTreasury.modifyParameters('extraSurplusReceiver', abi.encode(_extraSurplusReceiver));

    assertEq(_extraSurplusReceiver, stabilityFeeTreasury.extraSurplusReceiver());
  }

  function test_Revert_ModifyParameters_UnrecognizedParam() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    stabilityFeeTreasury.modifyParameters('unrecognizedParam', abi.encode(0));
  }

  function test_Revert_ModifyParameters_ExtraSurplusReceiver() public authorized {
    vm.expectRevert(Assertions.NullAddress.selector);

    stabilityFeeTreasury.modifyParameters('extraSurplusReceiver', abi.encode(0));
  }
}

contract Unit_StabilityFeeTreasury_DisableContract is Base {
  event DisableContract();
  event JoinCoins(uint256 _wad);

  struct DisableContractScenario {
    uint256 systemCoinBalance;
    uint256 safeEngineCoinBalance;
  }

  function _joinCoins(DisableContractScenario memory _disableContractScenario) internal pure returns (bool) {
    return _disableContractScenario.systemCoinBalance > 0;
  }

  function _mockValues(DisableContractScenario memory _disableContractScenario) internal {
    _mockSystemCoinBalanceOf(_disableContractScenario.systemCoinBalance);
    _mockSafeEngineCoinBalance(_disableContractScenario.safeEngineCoinBalance);
  }

  modifier happyPath(DisableContractScenario memory _disableContractScenario) {
    _mockValues(_disableContractScenario);
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Emit_JoinCoins(DisableContractScenario memory _disableContractScenario)
    public
    happyPath(_disableContractScenario)
  {
    vm.assume(_joinCoins(_disableContractScenario));

    vm.expectEmit();
    emit JoinCoins(_disableContractScenario.systemCoinBalance);

    stabilityFeeTreasury.disableContract();
  }

  function test_Call_SafeEngine_TransferInternalCoins(DisableContractScenario memory _disableContractScenario)
    public
    happyPath(_disableContractScenario)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (address(stabilityFeeTreasury), mockExtraSurplusReceiver, _disableContractScenario.safeEngineCoinBalance)
      ),
      1
    );

    stabilityFeeTreasury.disableContract();
  }
}

contract Unit_StabilityFeeTreasury_JoinAllCoins is Base {
  event JoinCoins(uint256 _wad);

  function _joinCoins(uint256 _systemCoinBalance) internal pure returns (bool) {
    return _systemCoinBalance > 0;
  }

  modifier happyPath(uint256 _systemCoinBalance) {
    _mockSystemCoinBalanceOf(_systemCoinBalance);
    _;
  }

  function test_Call_CoinJoin_Join(uint256 _systemCoinBalance) public happyPath(_systemCoinBalance) {
    vm.assume(_joinCoins(_systemCoinBalance));

    vm.expectCall(
      address(mockCoinJoin), abi.encodeCall(mockCoinJoin.join, (address(stabilityFeeTreasury), _systemCoinBalance)), 1
    );

    stabilityFeeTreasury.joinAllCoins();
  }

  function test_Emit_JoinCoins(uint256 _systemCoinBalance) public happyPath(_systemCoinBalance) {
    vm.assume(_joinCoins(_systemCoinBalance));

    vm.expectEmit();
    emit JoinCoins(_systemCoinBalance);

    stabilityFeeTreasury.joinAllCoins();
  }

  function testFail_Emit_JoinCoins(uint256 _systemCoinBalance) public happyPath(_systemCoinBalance) {
    vm.assume(!_joinCoins(_systemCoinBalance));

    vm.expectEmit(false, false, false, false);
    emit JoinCoins(_systemCoinBalance);

    stabilityFeeTreasury.joinAllCoins();
  }
}

contract Unit_StabilityFeeTreasury_SettleDebt is Base {
  event SettleDebt(uint256 _rad);

  struct SettleDebtScenario {
    uint256 safeEngineCoinBalance;
    uint256 safeEngineDebtBalance;
  }

  function _settleDebt(SettleDebtScenario memory _settleDebtScenario) internal pure returns (bool) {
    return _settleDebtScenario.safeEngineDebtBalance > 0;
  }

  function _mockValues(SettleDebtScenario memory _settleDebtScenario) internal {
    _mockSafeEngineCoinBalance(_settleDebtScenario.safeEngineCoinBalance);
    _mockSafeEngineDebtBalance(_settleDebtScenario.safeEngineDebtBalance);
  }

  modifier happyPath(SettleDebtScenario memory _settleDebtScenario) {
    _mockValues(_settleDebtScenario);
    _;
  }

  function test_Call_SafeEngine_SettleDebt(SettleDebtScenario memory _settleDebtScenario)
    public
    happyPath(_settleDebtScenario)
  {
    vm.assume(_settleDebt(_settleDebtScenario));

    uint256 _debtToSettle =
      Math.min(_settleDebtScenario.safeEngineCoinBalance, _settleDebtScenario.safeEngineDebtBalance);

    vm.expectCall(address(mockSafeEngine), abi.encodeCall(mockSafeEngine.settleDebt, (_debtToSettle)), 1);

    stabilityFeeTreasury.settleDebt();
  }

  function test_Emit_SettleDebt(SettleDebtScenario memory _settleDebtScenario) public happyPath(_settleDebtScenario) {
    vm.assume(_settleDebt(_settleDebtScenario));

    uint256 _debtToSettle =
      Math.min(_settleDebtScenario.safeEngineCoinBalance, _settleDebtScenario.safeEngineDebtBalance);

    vm.expectEmit();
    emit SettleDebt(_debtToSettle);

    stabilityFeeTreasury.settleDebt();
  }

  function test_Return_SafeEngineBalances_SettleDebt(SettleDebtScenario memory _settleDebtScenario)
    public
    happyPath(_settleDebtScenario)
  {
    vm.assume(_settleDebt(_settleDebtScenario));

    uint256 _debtToSettle =
      Math.min(_settleDebtScenario.safeEngineCoinBalance, _settleDebtScenario.safeEngineDebtBalance);

    (uint256 _coinBalance, uint256 _debtBalance) = stabilityFeeTreasury.settleDebt();

    assertEq(_coinBalance, _settleDebtScenario.safeEngineCoinBalance - _debtToSettle);
    assertEq(_debtBalance, _settleDebtScenario.safeEngineDebtBalance - _debtToSettle);
  }

  function test_Return_SafeEngineBalances_NoDebt(SettleDebtScenario memory _settleDebtScenario)
    public
    happyPath(_settleDebtScenario)
  {
    vm.assume(!_settleDebt(_settleDebtScenario));

    (uint256 _coinBalance, uint256 _debtBalance) = stabilityFeeTreasury.settleDebt();

    assertEq(_coinBalance, _settleDebtScenario.safeEngineCoinBalance);
    assertEq(_debtBalance, _settleDebtScenario.safeEngineDebtBalance);
  }
}

contract Unit_StabilityFeeTreasury_SetTotalAllowance is Base {
  event SetTotalAllowance(address indexed _account, uint256 _rad);

  function _notNullAcc(address _account) internal pure returns (bool) {
    return _account != address(0);
  }

  function _notStabilityFeeTreasuryAcc(address _account) internal view returns (bool) {
    return _account != address(stabilityFeeTreasury);
  }

  function _assumeHappyPath(address _account) internal view {
    vm.assume(_notNullAcc(_account));
    vm.assume(_notStabilityFeeTreasuryAcc(_account));
  }

  modifier happyPath(address _account) {
    _assumeHappyPath(_account);
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_Allowance(address _account, uint256 _rad) public happyPath(_account) {
    stabilityFeeTreasury.setTotalAllowance(_account, _rad);

    assertEq(stabilityFeeTreasury.allowance(_account).total, _rad);
  }

  function test_Emit_SetTotalAllowance(address _account, uint256 _rad) public happyPath(_account) {
    vm.expectEmit();
    emit SetTotalAllowance(_account, _rad);

    stabilityFeeTreasury.setTotalAllowance(_account, _rad);
  }

  function test_Revert_Unauthorized(address _account, uint256 _rad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.setTotalAllowance(_account, _rad);
  }

  function test_Revert_NullAccount(uint256 _rad) public authorized {
    vm.expectRevert(Assertions.NullAddress.selector);

    stabilityFeeTreasury.setTotalAllowance(address(0), _rad);
  }

  function test_Revert_AccountCannotBeTreasury(uint256 _rad) public authorized {
    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_AccountCannotBeTreasury.selector);

    stabilityFeeTreasury.setTotalAllowance(address(stabilityFeeTreasury), _rad);
  }
}

contract Unit_StabilityFeeTreasury_SetPerHourAllowance is Base {
  event SetPerHourAllowance(address indexed _account, uint256 _rad);

  function _notNullAcc(address _account) internal pure returns (bool) {
    return _account != address(0);
  }

  function _notStabilityFeeTreasuryAcc(address _account) internal view returns (bool) {
    return _account != address(stabilityFeeTreasury);
  }

  function _assumeHappyPath(address _account) internal view {
    vm.assume(_notNullAcc(_account));
    vm.assume(_notStabilityFeeTreasuryAcc(_account));
  }

  modifier happyPath(address _account) {
    _assumeHappyPath(_account);
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_Allowance(address _account, uint256 _rad) public happyPath(_account) {
    stabilityFeeTreasury.setPerHourAllowance(_account, _rad);

    assertEq(stabilityFeeTreasury.allowance(_account).perHour, _rad);
  }

  function test_Emit_SetPerHourAllowance(address _account, uint256 _rad) public happyPath(_account) {
    vm.expectEmit();
    emit SetPerHourAllowance(_account, _rad);

    stabilityFeeTreasury.setPerHourAllowance(_account, _rad);
  }

  function test_Revert_Unauthorized(address _account, uint256 _rad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.setTotalAllowance(_account, _rad);
  }

  function test_Revert_NullAccount(uint256 _rad) public authorized {
    vm.expectRevert(Assertions.NullAddress.selector);

    stabilityFeeTreasury.setPerHourAllowance(address(0), _rad);
  }

  function test_Revert_AccountCannotBeTreasury(uint256 _rad) public authorized {
    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_AccountCannotBeTreasury.selector);

    stabilityFeeTreasury.setPerHourAllowance(address(stabilityFeeTreasury), _rad);
  }
}

contract Unit_StabilityFeeTreasury_GiveFunds is Base {
  event GiveFunds(address indexed _account, uint256 _rad);
  event JoinCoins(uint256 _wad);
  event SettleDebt(uint256 _rad);

  struct GiveFundsScenario {
    address account;
    uint256 rad;
    uint256 systemCoinBalance;
    uint256 safeEngineCoinBalance;
    uint256 safeEngineDebtBalance;
  }

  function _notNullAcc(GiveFundsScenario memory _giveFundsScenario) internal pure returns (bool) {
    return _giveFundsScenario.account != address(0);
  }

  function _notStabilityFeeTreasuryAcc(GiveFundsScenario memory _giveFundsScenario) internal view returns (bool) {
    return _giveFundsScenario.account != address(stabilityFeeTreasury);
  }

  function _joinCoins(GiveFundsScenario memory _giveFundsScenario) internal pure returns (bool) {
    return _giveFundsScenario.systemCoinBalance > 0;
  }

  function _settleDebt(GiveFundsScenario memory _giveFundsScenario) internal pure returns (bool) {
    return _giveFundsScenario.safeEngineDebtBalance > 0;
  }

  function _nullDebt(GiveFundsScenario memory _giveFundsScenario) internal pure returns (bool) {
    return _giveFundsScenario.safeEngineCoinBalance >= _giveFundsScenario.safeEngineDebtBalance;
  }

  function _enoughFunds(GiveFundsScenario memory _giveFundsScenario) internal pure returns (bool) {
    return _giveFundsScenario.safeEngineCoinBalance - _giveFundsScenario.safeEngineDebtBalance >= _giveFundsScenario.rad;
  }

  function _assumeHappyPath(GiveFundsScenario memory _giveFundsScenario) internal view {
    vm.assume(_notNullAcc(_giveFundsScenario));
    vm.assume(_notStabilityFeeTreasuryAcc(_giveFundsScenario));
    vm.assume(_nullDebt(_giveFundsScenario));
    vm.assume(_enoughFunds(_giveFundsScenario));
  }

  function _mockValues(GiveFundsScenario memory _giveFundsScenario) internal {
    _mockSystemCoinBalanceOf(_giveFundsScenario.systemCoinBalance);
    _mockSafeEngineCoinBalance(_giveFundsScenario.safeEngineCoinBalance);
    _mockSafeEngineDebtBalance(_giveFundsScenario.safeEngineDebtBalance);
  }

  modifier happyPath(GiveFundsScenario memory _giveFundsScenario) {
    _assumeHappyPath(_giveFundsScenario);
    _mockValues(_giveFundsScenario);
    _;
  }

  function test_Emit_JoinCoins(GiveFundsScenario memory _giveFundsScenario)
    public
    authorized
    happyPath(_giveFundsScenario)
  {
    vm.assume(_joinCoins(_giveFundsScenario));

    vm.expectEmit();
    emit JoinCoins(_giveFundsScenario.systemCoinBalance);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Emit_SettleDebt(GiveFundsScenario memory _giveFundsScenario)
    public
    authorized
    happyPath(_giveFundsScenario)
  {
    vm.assume(_settleDebt(_giveFundsScenario));

    vm.expectEmit();
    emit SettleDebt(_giveFundsScenario.safeEngineDebtBalance);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Call_SafeEngine_TransferInternalCoins(GiveFundsScenario memory _giveFundsScenario)
    public
    authorized
    happyPath(_giveFundsScenario)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (address(stabilityFeeTreasury), _giveFundsScenario.account, _giveFundsScenario.rad)
      ),
      1
    );

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Emit_GiveFunds(GiveFundsScenario memory _giveFundsScenario)
    public
    authorized
    happyPath(_giveFundsScenario)
  {
    vm.expectEmit();
    emit GiveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Revert_Unauthorized(GiveFundsScenario memory _giveFundsScenario) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Revert_NullAccount(GiveFundsScenario memory _giveFundsScenario) public authorized {
    _giveFundsScenario.account = address(0);

    vm.expectRevert(Assertions.NullAddress.selector);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Revert_AccountCannotBeTreasury(GiveFundsScenario memory _giveFundsScenario) public authorized {
    _giveFundsScenario.account = address(stabilityFeeTreasury);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_AccountCannotBeTreasury.selector);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Revert_OutstandingBadDebt(GiveFundsScenario memory _giveFundsScenario) public authorized {
    vm.assume(_notNullAcc(_giveFundsScenario));
    vm.assume(_notStabilityFeeTreasuryAcc(_giveFundsScenario));

    vm.assume(!_nullDebt(_giveFundsScenario));
    _mockValues(_giveFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_OutstandingBadDebt.selector);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }

  function test_Revert_NotEnoughFunds(GiveFundsScenario memory _giveFundsScenario) public authorized {
    vm.assume(_notNullAcc(_giveFundsScenario));
    vm.assume(_notStabilityFeeTreasuryAcc(_giveFundsScenario));
    vm.assume(_nullDebt(_giveFundsScenario));

    vm.assume(!_enoughFunds(_giveFundsScenario));
    _mockValues(_giveFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_NotEnoughFunds.selector);

    stabilityFeeTreasury.giveFunds(_giveFundsScenario.account, _giveFundsScenario.rad);
  }
}

contract Unit_StabilityFeeTreasury_TakeFunds is Base {
  event TakeFunds(address indexed _account, uint256 _rad);

  function _notStabilityFeeTreasuryAcc(address _account) internal view returns (bool) {
    return _account != address(stabilityFeeTreasury);
  }

  function _assumeHappyPath(address _account) internal view {
    vm.assume(_notStabilityFeeTreasuryAcc(_account));
  }

  modifier happyPath(address _account) {
    _assumeHappyPath(_account);
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Call_SafeEngine_TransferInternalCoins(address _account, uint256 _rad) public happyPath(_account) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (_account, address(stabilityFeeTreasury), _rad)),
      1
    );

    stabilityFeeTreasury.takeFunds(_account, _rad);
  }

  function test_Emit_TakeFunds(address _account, uint256 _rad) public happyPath(_account) {
    vm.expectEmit();
    emit TakeFunds(_account, _rad);

    stabilityFeeTreasury.takeFunds(_account, _rad);
  }

  function test_Revert_Unauthorized(address _account, uint256 _rad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.takeFunds(_account, _rad);
  }

  function test_Revert_AccountCannotBeTreasury(uint256 _rad) public authorized {
    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_AccountCannotBeTreasury.selector);

    stabilityFeeTreasury.takeFunds(address(stabilityFeeTreasury), _rad);
  }
}

contract Unit_StabilityFeeTreasury_PullFunds is Base {
  event PullFunds(address indexed _sender, address indexed _dstAccount, uint256 _rad);
  event JoinCoins(uint256 _wad);
  event SettleDebt(uint256 _rad);

  struct PullFundsScenario {
    address dstAccount;
    uint256 wad;
    uint256 totalAllowance;
    uint256 allowancePerHour;
    uint256 initialPulledPerHour;
    uint256 systemCoinBalance;
    uint256 safeEngineCoinBalance;
    uint256 safeEngineDebtBalance;
    uint256 pullFundsMinThreshold;
  }

  function _notNullDstAcc(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.dstAccount != address(0); // avoid null dst-acc error
  }

  function _notStabilityFeeTreasuryDstAcc(PullFundsScenario memory _pullFundsScenario) internal view returns (bool) {
    return _pullFundsScenario.dstAccount != address(stabilityFeeTreasury);
  }

  function _notAccountingDstAcc(PullFundsScenario memory _pullFundsScenario) internal view returns (bool) {
    return _pullFundsScenario.dstAccount != address(mockExtraSurplusReceiver);
  }

  function _notNullTransferAmount(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.wad > 0; // avoid null transfer amount error
  }

  function _allowed(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    vm.assume(notOverflowMul(_pullFundsScenario.wad, RAY)); // notOverflow
    return _pullFundsScenario.totalAllowance >= _pullFundsScenario.wad * RAY; // avoid not allowed error
  }

  function _allowancePerHourNotZero(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.allowancePerHour > 0; // enter if statement for require
  }

  function _notPerHourLimitExceeded(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    vm.assume(notOverflowAdd(_pullFundsScenario.initialPulledPerHour, _pullFundsScenario.wad * RAY));
    return
      _pullFundsScenario.initialPulledPerHour + (_pullFundsScenario.wad * RAY) <= _pullFundsScenario.allowancePerHour; // avoid StabilityFeeTreasury/per-hour-limit-exceeded
  }

  function _joinCoins(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.systemCoinBalance > 0;
  }

  function _settleDebt(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.safeEngineDebtBalance > 0;
  }

  function _nullDebt(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.safeEngineCoinBalance >= _pullFundsScenario.safeEngineDebtBalance;
  }

  function _enoughFunds(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.safeEngineCoinBalance - _pullFundsScenario.safeEngineDebtBalance
      >= _pullFundsScenario.wad * RAY; // avoid StabilityFeeTreasury/not-enough-funds
  }

  function _notBelowPullFundsMinThreshold(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario.safeEngineCoinBalance - _pullFundsScenario.safeEngineDebtBalance
      >= _pullFundsScenario.pullFundsMinThreshold; // avoid StabilityFeeTreasury/below-pullFunds-min-threshold
  }

  function _assumeHappyPath(PullFundsScenario memory _pullFundsScenario) internal view {
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmount(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));
    vm.assume(_nullDebt(_pullFundsScenario));
    vm.assume(_enoughFunds(_pullFundsScenario));
    vm.assume(_notBelowPullFundsMinThreshold(_pullFundsScenario));
  }

  function _mockValues(PullFundsScenario memory _pullFundsScenario) internal {
    _mockTotalAllowance(user, _pullFundsScenario.totalAllowance);
    _mockPerHourAllowance(user, _pullFundsScenario.allowancePerHour);
    _mockPulledPerHour(user, block.timestamp / HOUR, _pullFundsScenario.initialPulledPerHour);
    _mockSystemCoinBalanceOf(_pullFundsScenario.systemCoinBalance);
    _mockSafeEngineCoinBalance(_pullFundsScenario.safeEngineCoinBalance);
    _mockSafeEngineDebtBalance(_pullFundsScenario.safeEngineDebtBalance);
    _mockPullFundsMinThreshold(_pullFundsScenario.pullFundsMinThreshold);
  }

  modifier happyPath(PullFundsScenario memory _pullFundsScenario) {
    _assumeHappyPath(_pullFundsScenario);
    _mockValues(_pullFundsScenario);
    vm.startPrank(user);
    _;
  }

  function test_Set_PulledPerHour(PullFundsScenario memory _pullFundsScenario) public happyPath(_pullFundsScenario) {
    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);

    assertEq(
      stabilityFeeTreasury.pulledPerHour(user, block.timestamp / HOUR),
      _pullFundsScenario.initialPulledPerHour + (_pullFundsScenario.wad * RAY)
    );
  }

  function test_Emit_JoinCoins(PullFundsScenario memory _pullFundsScenario) public happyPath(_pullFundsScenario) {
    vm.assume(_joinCoins(_pullFundsScenario));

    vm.expectEmit();
    emit JoinCoins(_pullFundsScenario.systemCoinBalance);

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Emit_SettleDebt(PullFundsScenario memory _pullFundsScenario) public happyPath(_pullFundsScenario) {
    vm.assume(_settleDebt(_pullFundsScenario));

    vm.expectEmit();
    emit SettleDebt(_pullFundsScenario.safeEngineDebtBalance);

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Set_Allowance(PullFundsScenario memory _pullFundsScenario) public happyPath(_pullFundsScenario) {
    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);

    assertEq(
      stabilityFeeTreasury.allowance(user).total, _pullFundsScenario.totalAllowance - (_pullFundsScenario.wad * RAY)
    );
  }

  function test_Call_SafeEngine_TransferInternalCoins(PullFundsScenario memory _pullFundsScenario)
    public
    happyPath(_pullFundsScenario)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (address(stabilityFeeTreasury), _pullFundsScenario.dstAccount, _pullFundsScenario.wad * RAY)
      ),
      1
    );

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Emit_PullFunds(PullFundsScenario memory _pullFundsScenario) public happyPath(_pullFundsScenario) {
    vm.expectEmit();
    emit PullFunds(user, _pullFundsScenario.dstAccount, _pullFundsScenario.wad * RAY);

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_NullDst(PullFundsScenario memory _pullFundsScenario) public {
    _pullFundsScenario.dstAccount = address(0);

    vm.expectRevert(Assertions.NullAddress.selector);

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function testFail_Emit_PullFunds_DstAccIsStabilityFeeTreasury(PullFundsScenario memory _pullFundsScenario) public {
    _pullFundsScenario.dstAccount = address(stabilityFeeTreasury);

    vm.expectEmit(false, false, false, false);
    emit PullFunds(user, address(stabilityFeeTreasury), _pullFundsScenario.wad * RAY);

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_DstCannotBeAccounting(PullFundsScenario memory _pullFundsScenario) public {
    _pullFundsScenario.dstAccount = address(mockExtraSurplusReceiver);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_DstCannotBeAccounting.selector);

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_NullTransferAmount(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));

    _pullFundsScenario.wad = 0;

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_NullTransferAmount.selector);

    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_NotAllowed(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmount(_pullFundsScenario));

    vm.assume(!_allowed(_pullFundsScenario));
    _mockValues(_pullFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_NotAllowed.selector);

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_PerHourLimitExceeded(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmount(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));

    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(!_notPerHourLimitExceeded(_pullFundsScenario));
    _mockValues(_pullFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_PerHourLimitExceeded.selector);

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_OutstandingBadDebt(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmount(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));

    vm.assume(!_nullDebt(_pullFundsScenario));
    _mockValues(_pullFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_OutstandingBadDebt.selector);

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_NotEnoughFunds(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmount(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));
    vm.assume(_nullDebt(_pullFundsScenario));

    vm.assume(!_enoughFunds(_pullFundsScenario));
    _mockValues(_pullFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_NotEnoughFunds.selector);

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }

  function test_Revert_BelowPullFundsMinThreshold(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmount(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));
    vm.assume(_nullDebt(_pullFundsScenario));
    vm.assume(_enoughFunds(_pullFundsScenario));

    vm.assume(!_notBelowPullFundsMinThreshold(_pullFundsScenario));
    _mockValues(_pullFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_BelowPullFundsMinThreshold.selector);

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario.dstAccount, _pullFundsScenario.wad);
  }
}

contract Unit_StabilityFeeTreasury_TransferSurplusFunds is Base {
  event TransferSurplusFunds(address _extraSurplusReceiver, uint256 _fundsToTransfer);
  event JoinCoins(uint256 _wad);
  event SettleDebt(uint256 _rad);

  struct TransferSurplusFundsScenario {
    uint256 treasuryCapacity;
    uint256 systemCoinBalance;
    uint256 safeEngineCoinBalance;
    uint256 safeEngineDebtBalance;
  }

  function _joinCoins(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) internal pure returns (bool) {
    return _transferSurplusFundsScenario.systemCoinBalance > 0;
  }

  function _settleDebt(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) internal pure returns (bool) {
    return _transferSurplusFundsScenario.safeEngineDebtBalance > 0;
  }

  function _nullDebt(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) internal pure returns (bool) {
    return _transferSurplusFundsScenario.safeEngineCoinBalance >= _transferSurplusFundsScenario.safeEngineDebtBalance;
  }

  function _enoughSurplus(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    internal
    pure
    returns (bool)
  {
    return _transferSurplusFundsScenario.safeEngineCoinBalance - _transferSurplusFundsScenario.safeEngineDebtBalance
      > _transferSurplusFundsScenario.treasuryCapacity;
  }

  function _assumeHappyPath(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) internal pure {
    vm.assume(_nullDebt(_transferSurplusFundsScenario));
    vm.assume(_enoughSurplus(_transferSurplusFundsScenario));
  }

  function _mockValues(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) internal {
    _mockTreasuryCapacity(_transferSurplusFundsScenario.treasuryCapacity);
    _mockSystemCoinBalanceOf(_transferSurplusFundsScenario.systemCoinBalance);
    _mockSafeEngineCoinBalance(_transferSurplusFundsScenario.safeEngineCoinBalance);
    _mockSafeEngineDebtBalance(_transferSurplusFundsScenario.safeEngineDebtBalance);
  }

  modifier happyPath(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) {
    _assumeHappyPath(_transferSurplusFundsScenario);
    _mockValues(_transferSurplusFundsScenario);
    _;
  }

  function test_Emit_JoinCoins(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPath(_transferSurplusFundsScenario)
  {
    vm.assume(_joinCoins(_transferSurplusFundsScenario));

    vm.expectEmit();
    emit JoinCoins(_transferSurplusFundsScenario.systemCoinBalance);

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Emit_SettleDebt(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPath(_transferSurplusFundsScenario)
  {
    vm.assume(_settleDebt(_transferSurplusFundsScenario));

    vm.expectEmit();
    emit SettleDebt(_transferSurplusFundsScenario.safeEngineDebtBalance);

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Set_LatestSurplusTransferTime(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario,
    uint256 _latestSurplusTransferTime
  ) public happyPath(_transferSurplusFundsScenario) {
    vm.assume(_latestSurplusTransferTime < block.timestamp);
    _mockLatestSurplusTransferTime(_latestSurplusTransferTime);

    stabilityFeeTreasury.transferSurplusFunds();

    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
  }

  function test_Call_SafeEngine_TransferInternalCoins(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPath(_transferSurplusFundsScenario)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (
          address(stabilityFeeTreasury),
          mockExtraSurplusReceiver,
          (_transferSurplusFundsScenario.safeEngineCoinBalance - _transferSurplusFundsScenario.safeEngineDebtBalance)
            - _transferSurplusFundsScenario.treasuryCapacity
        )
      ),
      1
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Emit_TransferSurplusFunds(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPath(_transferSurplusFundsScenario)
  {
    vm.expectEmit();
    emit TransferSurplusFunds(
      mockExtraSurplusReceiver,
      (_transferSurplusFundsScenario.safeEngineCoinBalance - _transferSurplusFundsScenario.safeEngineDebtBalance)
        - _transferSurplusFundsScenario.treasuryCapacity
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Revert_TransferCooldownNotPassed(uint256 _surplusTransferDelay) public {
    vm.assume(_surplusTransferDelay > 0);
    vm.assume(notOverflowAdd(block.timestamp, _surplusTransferDelay));
    _mockSurplusTransferDelay(_surplusTransferDelay);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_TransferCooldownNotPassed.selector);

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Revert_OutstandingBadDebt(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) public {
    vm.assume(!_nullDebt(_transferSurplusFundsScenario));
    _mockValues(_transferSurplusFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_OutstandingBadDebt.selector);

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Revert_NotEnoughSurplus(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) public {
    vm.assume(_nullDebt(_transferSurplusFundsScenario));

    vm.assume(!_enoughSurplus(_transferSurplusFundsScenario));
    _mockValues(_transferSurplusFundsScenario);

    vm.expectRevert(IStabilityFeeTreasury.SFTreasury_NotEnoughSurplus.selector);

    stabilityFeeTreasury.transferSurplusFunds();
  }
}
