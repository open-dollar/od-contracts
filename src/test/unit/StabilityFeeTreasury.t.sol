// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ISystemCoin} from '@interfaces/external/ISystemCoin.sol';
import {StabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {
  StabilityFeeTreasuryForTest,
  StabilityFeeTreasuryForInternalCallsTest
} from '@contracts/for-test/StabilityFeeTreasuryForTest.sol';
import {Math, RAY, WAD, HOUR, HUNDRED} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  // Events to test internal calls
  event CalledJoinAllCoins();
  event CalledSettleDebt();

  address mockExtraSurplusReceiver = label('surplusReceiver');
  address deployer = label('deployer');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('mockSafeEngine'));
  ICoinJoin mockCoinJoin = ICoinJoin(mockContract('coinJoin'));
  ISystemCoin mockSystemCoin = ISystemCoin(mockContract('systemCoin'));
  IStabilityFeeTreasury stabilityFeeTreasury;

  function _mockCoinJoinSystemCoin(address _systemCoin) internal {
    vm.mockCall(address(mockCoinJoin), abi.encodeWithSelector(ICoinJoin.systemCoin.selector), abi.encode(_systemCoin));
  }

  function _mockSystemCoinApprove(address _account, uint256 _amount, bool _success) internal {
    vm.mockCall(
      address(mockSystemCoin),
      abi.encodeWithSelector(ISystemCoin.approve.selector, _account, _amount),
      abi.encode(_success)
    );
  }

  function _mockSystemCoinsBalanceOf(uint256 _balance) internal {
    vm.mockCall(
      address(mockSystemCoin),
      abi.encodeWithSelector(ISystemCoin.balanceOf.selector, address(stabilityFeeTreasury)),
      abi.encode(_balance)
    );
  }

  function _mockCoinJoinJoin() internal {
    vm.mockCall(
      address(mockCoinJoin),
      abi.encodeWithSelector(
        ICoinJoin.join.selector, address(stabilityFeeTreasury), mockSystemCoin.balanceOf(address(stabilityFeeTreasury))
      ),
      abi.encode(0)
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

  function _mockSafeEngineTransferInternalCoins() internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        mockSafeEngine.coinBalance(address(stabilityFeeTreasury))
      ),
      abi.encode(0)
    );
  }

  function _mockContractEnabled(uint256 _enabled) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IDisableable.contractEnabled.selector).checked_write(_enabled);
  }

  function _mockExpensesAccumulator(uint256 _expensesAccumulator) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.expensesAccumulator.selector).checked_write(
      _expensesAccumulator
    );
  }

  function _mockSafeEngineSettleDebt(uint256 _rad) internal {
    vm.mockCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _rad), abi.encode(0));
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

  function _mockAccumulatorTag(uint256 _tag) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.accumulatorTag.selector).checked_write(
      _tag
    );
  }

  function _mockLatestSurplusTransferTime(uint256 _latestSurplusTransferTime) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.latestSurplusTransferTime.selector)
      .checked_write(_latestSurplusTransferTime);
  }

  // params

  function _mockExpensesMultiplier(uint256 _multiplier) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(0).checked_write(
      _multiplier
    );
  }

  function _mockTreasuryCapacity(uint256 _capacity) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(1).checked_write(
      _capacity
    );
  }

  function _mockMinimumFundsRequired(uint256 _minFundsRequired) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(2).checked_write(
      _minFundsRequired
    );
  }

  function _mockPullFundsMinThreshold(uint256 _value) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(3).checked_write(
      _value
    );
  }

  function _mockSurplusTransferDelay(uint256 _surplusTransferDelay) internal {
    stdstore.target(address(stabilityFeeTreasury)).sig(IStabilityFeeTreasury.params.selector).depth(4).checked_write(
      _surplusTransferDelay
    );
  }

  function setUp() public virtual {
    _mockCoinJoinSystemCoin(address(mockSystemCoin));
    _mockSystemCoinApprove(address(mockCoinJoin), type(uint256).max, true);

    vm.prank(deployer);
    stabilityFeeTreasury =
      new StabilityFeeTreasury(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }
}

contract Unit_StabilityFeeTreasury_Constructor is Base {
  function test_Set_SafeEngine() public {
    assertEq(address(stabilityFeeTreasury.safeEngine()), address(mockSafeEngine));
  }

  function test_Set_ExtraSurplusReceiver() public {
    assertEq(address(stabilityFeeTreasury.extraSurplusReceiver()), mockExtraSurplusReceiver);
  }

  function test_Set_CoinJoin() public {
    assertEq(address(stabilityFeeTreasury.coinJoin()), address(mockCoinJoin));
  }

  function test_Set_SystemCoin() public {
    assertEq(address(stabilityFeeTreasury.systemCoin()), address(mockSystemCoin));
  }

  function test_Set_LatestSurplusTransferTime() public {
    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
  }

  function test_Set_ExpensesMultiplier() public {
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _params = stabilityFeeTreasury.params();
    assertEq(_params.expensesMultiplier, 100);
  }

  function test_Set_ContractEnabled() public {
    assertEq(stabilityFeeTreasury.contractEnabled(), 1);
  }

  function test_Call_SystemCoin_Approve() public {
    vm.expectCall(
      address(mockSystemCoin),
      abi.encodeWithSelector(ISystemCoin.approve.selector, address(mockCoinJoin), type(uint256).max)
    );
    stabilityFeeTreasury =
      new StabilityFeeTreasury(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));
  }

  function test_Revert_NullSystemCoin() public {
    _mockCoinJoinSystemCoin(address(0));

    vm.expectRevert(bytes('StabilityFeeTreasury/null-system-coin'));
    stabilityFeeTreasury =
      new StabilityFeeTreasury(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));
  }

  function test_Revert_NullSurplusReceiver() public {
    vm.expectRevert(bytes('StabilityFeeTreasury/null-surplus-receiver'));

    stabilityFeeTreasury = new StabilityFeeTreasury(address(mockSafeEngine), address(0), address(mockCoinJoin));
  }
}

contract Unit_StabilityFeeTreasury_ModifyParameters is Base {
  function test_ModifyParameters(IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _fuzz) public authorized {
    vm.assume(_fuzz.treasuryCapacity >= _fuzz.minFundsRequired);

    stabilityFeeTreasury.modifyParameters('expensesMultiplier', abi.encode(_fuzz.expensesMultiplier));
    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(_fuzz.treasuryCapacity));
    stabilityFeeTreasury.modifyParameters('minimumFundsRequired', abi.encode(_fuzz.minFundsRequired));
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

contract Unit_StabilityFeeTreasuty_DisableContract is Base {
  event DisableContract();

  function setUp() public virtual override {
    super.setUp();
    vm.prank(deployer);
    stabilityFeeTreasury =
    new StabilityFeeTreasuryForInternalCallsTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));

    _mockSystemCoinsBalanceOf(1);
    _mockCoinJoinJoin();
    _mockSafeEngineCoinBalance(1);
    _mockSafeEngineTransferInternalCoins();
  }

  function test_Set_ContractEnabled() public authorized {
    stabilityFeeTreasury.disableContract();
    assertEq(stabilityFeeTreasury.contractEnabled(), 0);
  }

  function test_Call_Internal_JoinAllCoins() public authorized {
    expectEmitNoIndex();
    emit CalledJoinAllCoins();

    stabilityFeeTreasury.disableContract();
  }

  function test_Call_SafeEngine_CoinBalance() public authorized {
    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(stabilityFeeTreasury))
    );

    stabilityFeeTreasury.disableContract();
  }

  function test_Call_SafeEngine_TransferInternalCoins() public authorized {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        mockSafeEngine.coinBalance(address(stabilityFeeTreasury))
      )
    );

    stabilityFeeTreasury.disableContract();
  }

  function test_Emit_DisableContract() public authorized {
    expectEmitNoIndex();
    emit DisableContract();

    stabilityFeeTreasury.disableContract();
  }

  function test_Revert_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.disableContract();
  }

  function test_Revert_AlreadyDisable() public authorized {
    _mockContractEnabled(0);
    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    stabilityFeeTreasury.disableContract();
  }
}

contract Unit_StabilityFeeTreasury_SettleDebt is Base {
  function setUp() public virtual override {
    super.setUp();
    _mockSafeEngineCoinBalance(1);
    _mockSafeEngineDebtBalance(1);
  }

  function test_Call_CoinBalance() public {
    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(stabilityFeeTreasury))
    );

    stabilityFeeTreasury.settleDebt();
  }

  function test_Call_DebtBalance() public {
    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.debtBalance.selector, address(stabilityFeeTreasury))
    );

    stabilityFeeTreasury.settleDebt();
  }

  function _mockValues(uint256 _coinBalance, uint256 _debtBalance) internal {
    _mockSafeEngineCoinBalance(_coinBalance);
    _mockSafeEngineDebtBalance(_debtBalance);

    if (_coinBalance < _debtBalance) {
      _mockSafeEngineSettleDebt(_coinBalance);
    } else {
      _mockSafeEngineSettleDebt(_debtBalance);
    }
  }

  function test_Call_SafeEngine_CoinBalanceLessOrEqualThanDebtBalance(
    uint256 _coinBalance,
    uint256 _debtBalance
  ) public {
    vm.assume(_debtBalance > 0);
    vm.assume(_coinBalance <= _debtBalance);

    _mockValues(_coinBalance, _debtBalance);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _coinBalance));

    stabilityFeeTreasury.settleDebt();
  }

  function test_Call_SafeEngine_DebtBalanceLessOrEqualThanCoinBalance(
    uint256 _coinBalance,
    uint256 _debtBalance
  ) public {
    vm.assume(_debtBalance > 0);
    vm.assume(_coinBalance >= _debtBalance);

    _mockValues(_coinBalance, _debtBalance);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _debtBalance));

    stabilityFeeTreasury.settleDebt();
  }

  function test_Not_Call_SafeEngine_DebtBalanceIsZero(uint256 _coinBalance) public {
    _mockValues(_coinBalance, 0);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, 0), 0);

    stabilityFeeTreasury.settleDebt();
  }
}

contract Unit_StabilityFeeTreasury_SetTotalAllowance is Base {
  event SetTotalAllowance(address indexed _account, uint256 _rad);

  function test_Set_Allowance(address _account, uint256 _rad) public authorized {
    vm.assume(_account != address(stabilityFeeTreasury) && _account != address(0));

    stabilityFeeTreasury.setTotalAllowance(_account, _rad);
    (uint256 _totalAllowance,) = stabilityFeeTreasury.allowance(_account);
    assertEq(_totalAllowance, _rad);
  }

  function test_Emit_SetTotalAllowance(address _account, uint256 _rad) public authorized {
    vm.assume(_account != address(stabilityFeeTreasury) && _account != address(0));
    vm.expectEmit(true, false, false, true);

    emit SetTotalAllowance(_account, _rad);

    stabilityFeeTreasury.setTotalAllowance(_account, _rad);
  }

  function test_Revert_NotAuthorized(address _account, uint256 _rad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.setTotalAllowance(_account, _rad);
  }

  function test_Revert_AccountIsTreasury() public authorized {
    vm.expectRevert(bytes('StabilityFeeTreasury/account-cannot-be-treasury'));

    stabilityFeeTreasury.setTotalAllowance(address(stabilityFeeTreasury), type(uint256).max);
  }

  function test_Revert_NullAccount() public authorized {
    vm.expectRevert(bytes('StabilityFeeTreasury/null-account'));

    stabilityFeeTreasury.setTotalAllowance(address(0), type(uint256).max);
  }
}

contract Unit_StabilityFeeTreasury_SetPerHourAllowance is Base {
  event SetPerHourAllowance(address indexed _account, uint256 _rad);

  function test_Set_Allowance(address _account, uint256 _rad) public authorized {
    vm.assume(_account != address(stabilityFeeTreasury) && _account != address(0));

    stabilityFeeTreasury.setPerHourAllowance(_account, _rad);
    (, uint256 _perHour) = stabilityFeeTreasury.allowance(_account);
    assertEq(_perHour, _rad);
  }

  function test_Emit_SetPerHourAllowance(address _account, uint256 _rad) public authorized {
    vm.assume(_account != address(stabilityFeeTreasury) && _account != address(0));
    vm.expectEmit(true, false, false, true);

    emit SetPerHourAllowance(_account, _rad);

    stabilityFeeTreasury.setPerHourAllowance(_account, _rad);
  }

  function test_Revert_NotAuthorized(address _account, uint256 _rad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.setTotalAllowance(_account, _rad);
  }

  function test_Revert_AccountIsTreasury() public authorized {
    vm.expectRevert(bytes('StabilityFeeTreasury/account-cannot-be-treasury'));

    stabilityFeeTreasury.setPerHourAllowance(address(stabilityFeeTreasury), type(uint256).max);
  }

  function test_Revert_NullAccount() public authorized {
    vm.expectRevert(bytes('StabilityFeeTreasury/null-account'));

    stabilityFeeTreasury.setPerHourAllowance(address(0), type(uint256).max);
  }
}

contract Unit_StabilityFeeTreasury_TakeFunds is Base {
  event TakeFunds(address indexed _account, uint256 _rad);

  function test_Call_SafeEngine_TransferCoins(address _account, uint256 _rad) public authorized {
    vm.assume(_account != address(stabilityFeeTreasury) && _account != address(0));

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.transferInternalCoins.selector, _account, address(stabilityFeeTreasury), _rad)
    );

    stabilityFeeTreasury.takeFunds(_account, _rad);
  }

  function test_Emit_TakeFunds(address _account, uint256 _rad) public authorized {
    vm.assume(_account != address(stabilityFeeTreasury) && _account != address(0));

    vm.expectEmit(true, false, false, true);
    emit TakeFunds(_account, _rad);

    stabilityFeeTreasury.takeFunds(_account, _rad);
  }

  function test_Revert_NotAuthorized(address _account, uint256 _rad) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.takeFunds(_account, _rad);
  }

  function test_Revert_AccountIsTreasury() public authorized {
    vm.expectRevert(bytes('StabilityFeeTreasury/account-cannot-be-treasury'));

    stabilityFeeTreasury.takeFunds(address(stabilityFeeTreasury), type(uint256).max);
  }
}

contract Unit_StabilityFeeTreasury_GiveFunds is Base {
  event GiveFunds(address indexed _account, uint256 _rad, uint256 _expensesAccumulator);

  function setUp() public virtual override {
    super.setUp();

    vm.prank(deployer);
    stabilityFeeTreasury =
    new StabilityFeeTreasuryForInternalCallsTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));
  }

  function _assumeHappyPath(address _account) internal view {
    vm.assume(
      _account != address(stabilityFeeTreasury) && _account != address(0) && _account != mockExtraSurplusReceiver
    );
  }

  function _mockValues(uint256 _coinBalance, uint256 _debtBalance) internal {
    _mockSafeEngineCoinBalance(_coinBalance);
    _mockSafeEngineDebtBalance(_debtBalance);
  }

  function test_Call_Internal_JoinAllCoins(address _account, uint256 _rad) public authorized {
    _assumeHappyPath(_account);
    _mockValues({_coinBalance: _rad, _debtBalance: 0});

    expectEmitNoIndex();
    emit CalledJoinAllCoins();

    stabilityFeeTreasury.giveFunds(_account, _rad);
  }

  function test_Call_Internal_SettleDebt(address _account, uint256 _rad) public authorized {
    _assumeHappyPath(_account);
    _mockValues({_coinBalance: _rad, _debtBalance: 0});

    expectEmitNoIndex();
    emit CalledSettleDebt();

    stabilityFeeTreasury.giveFunds(_account, _rad);
  }

  function test_Set_ExpensesAccumulator(
    address _account,
    uint256 _rad,
    uint256 _expensesInitialValue
  ) public authorized {
    _assumeHappyPath(_account);
    vm.assume(notOverflowAdd(_expensesInitialValue, _rad));

    _mockValues({_coinBalance: _rad, _debtBalance: 0});
    _mockExpensesAccumulator(_expensesInitialValue);

    stabilityFeeTreasury.giveFunds(_account, _rad);
    assertEq(stabilityFeeTreasury.expensesAccumulator(), _rad + _expensesInitialValue);
  }

  function test_Set_NotAddRadExpensesAccumulator(uint256 _rad, uint256 _expensesInitialValue) public authorized {
    _mockValues({_coinBalance: _rad, _debtBalance: 0});
    _mockExpensesAccumulator(_expensesInitialValue);

    stabilityFeeTreasury.giveFunds(mockExtraSurplusReceiver, _rad);
    assertEq(stabilityFeeTreasury.expensesAccumulator(), _expensesInitialValue);
  }

  function test_Call_SafeEngine_TransferInternalCoins(address _account, uint256 _rad) public authorized {
    _assumeHappyPath(_account);
    _mockValues({_coinBalance: _rad, _debtBalance: 0});

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (address(stabilityFeeTreasury), _account, _rad))
    );

    stabilityFeeTreasury.giveFunds(_account, _rad);
  }

  function test_Emit_GiveFunds(address _account, uint256 _rad, uint256 _expensesInitialValue) public authorized {
    _assumeHappyPath(_account);
    vm.assume(notOverflowAdd(_expensesInitialValue, _rad));

    _mockValues({_coinBalance: _rad, _debtBalance: 0});
    _mockExpensesAccumulator(_expensesInitialValue);

    vm.expectEmit(true, false, false, true);
    emit GiveFunds(_account, _rad, stabilityFeeTreasury.expensesAccumulator() + _rad);

    stabilityFeeTreasury.giveFunds(_account, _rad);
  }

  function test_Emit_GiveFunds_NotAddRadExpensesAccumulator(
    uint256 _rad,
    uint256 _expensesInitialValue
  ) public authorized {
    _mockValues({_coinBalance: _rad, _debtBalance: 0});
    _mockExpensesAccumulator(_expensesInitialValue);

    vm.expectEmit(true, false, false, true);
    emit GiveFunds(mockExtraSurplusReceiver, _rad, _expensesInitialValue);

    stabilityFeeTreasury.giveFunds(mockExtraSurplusReceiver, _rad);
  }

  function test_Revert_NotAuthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    stabilityFeeTreasury.giveFunds(mockExtraSurplusReceiver, 1);
  }

  function test_Revert_NullAccount() public authorized {
    vm.expectRevert(bytes('StabilityFeeTreasury/null-account'));

    stabilityFeeTreasury.giveFunds(address(0), 1);
  }

  function test_Revert_OutstandingBadDebt(address _account, uint256 _rad, uint256 _debt) public authorized {
    _assumeHappyPath(_account);
    vm.assume(_debt > 0);
    _mockValues({_coinBalance: _rad, _debtBalance: _debt});

    vm.expectRevert(bytes('StabilityFeeTreasury/outstanding-bad-debt'));

    stabilityFeeTreasury.giveFunds(_account, _rad);
  }

  function test_Revert_NotEnoughFunds(address _account, uint256 _rad, uint256 _initialBalance) public authorized {
    _assumeHappyPath(_account);
    vm.assume(_initialBalance < _rad);
    _mockValues({_coinBalance: _initialBalance, _debtBalance: 0});

    vm.expectRevert(bytes('StabilityFeeTreasury/not-enough-funds'));

    stabilityFeeTreasury.giveFunds(_account, _rad);
  }
}

contract Unit_StabilityFeeTreasury_PullFunds is Base {
  event PullFunds(address indexed _sender, address indexed _dstAccount, uint256 _rad, uint256 _expensesAccumulator);

  function setUp() public virtual override {
    super.setUp();

    vm.prank(deployer);
    stabilityFeeTreasury =
    new StabilityFeeTreasuryForInternalCallsTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));
  }

  struct PullFundsScenario {
    address _dstAccount;
    uint256 _wad;
    uint256 _totalAllowance;
    uint256 _allowancePerHour;
    uint256 _initialPulledPerHour;
    uint256 _safeEngineCoinBalance;
    uint256 _pullFundsMinThreshold;
    uint256 _initialExpensesAccumulator;
  }

  function _allowed(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    vm.assume(notOverflowMul(_pullFundsScenario._wad, RAY)); // notOverflow
    return _pullFundsScenario._totalAllowance >= _pullFundsScenario._wad * RAY; // avoid not allowed error
  }

  function _notNullDstAcc(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario._dstAccount != address(0); // avoid null dst-acc error
  }

  function _notAccountingDstAcc(PullFundsScenario memory _pullFundsScenario) internal view returns (bool) {
    return _pullFundsScenario._dstAccount != address(mockExtraSurplusReceiver);
  }

  function _notStabilityFeeTreasuryDstAcc(PullFundsScenario memory _pullFundsScenario) internal view returns (bool) {
    return _pullFundsScenario._dstAccount != address(stabilityFeeTreasury);
  }

  function _notNullTransferAmmount(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario._wad > 0; // avoid null transfer ammount error
  }

  function _allowancePerHourNotZero(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario._allowancePerHour > 0; //enter if statement for require
  }

  function _notPerHourLimitExceeded(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    vm.assume(notOverflowAdd(_pullFundsScenario._initialPulledPerHour, _pullFundsScenario._wad * RAY));
    return
      _pullFundsScenario._initialPulledPerHour + (_pullFundsScenario._wad * RAY) <= _pullFundsScenario._allowancePerHour; //avoid StabilityFeeTreasury/per-block-limit-exceeded
  }

  function _enoughFunds(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario._safeEngineCoinBalance >= _pullFundsScenario._wad * RAY; //avoid StabilityFeeTreasury/not-enough-funds
  }

  function _notBelowPullFundsMinThreshold(PullFundsScenario memory _pullFundsScenario) internal pure returns (bool) {
    return _pullFundsScenario._safeEngineCoinBalance >= _pullFundsScenario._pullFundsMinThreshold; // avoid StabilityFeeTreasury/below-pullFunds-min-threshold
  }

  function _notOverflowExpensesAccumulator(PullFundsScenario memory _pullFundsScenario) internal pure {
    vm.assume(notOverflowAdd(_pullFundsScenario._initialExpensesAccumulator, _pullFundsScenario._wad * RAY));
  }

  function _mockValues(PullFundsScenario memory _pullFundsScenario, uint256 _safeEngineDebtBalance) internal {
    _mockTotalAllowance(user, _pullFundsScenario._totalAllowance);
    _mockPerHourAllowance(user, _pullFundsScenario._allowancePerHour);
    _mockPulledPerHour(user, block.timestamp / HOUR, _pullFundsScenario._initialPulledPerHour);
    _mockSafeEngineDebtBalance(_safeEngineDebtBalance); // avoid StabilityFeeTreasury/outstanding-bad-debt
    _mockSafeEngineCoinBalance(_pullFundsScenario._safeEngineCoinBalance);
    _mockPullFundsMinThreshold(_pullFundsScenario._pullFundsMinThreshold);
    _mockExpensesAccumulator(_pullFundsScenario._initialExpensesAccumulator);
  }

  function _assumeHappyPathAllowancePerHourNotZero(PullFundsScenario memory _pullFundsScenario) internal view {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmmount(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));
    vm.assume(_enoughFunds(_pullFundsScenario));
    vm.assume(_notBelowPullFundsMinThreshold(_pullFundsScenario));
    _notOverflowExpensesAccumulator(_pullFundsScenario);
  }

  function _assumeHappyPathAllowancePerHourZero(PullFundsScenario memory _pullFundsScenario) internal view {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmmount(_pullFundsScenario));
    vm.assume(notOverflowAdd(_pullFundsScenario._initialPulledPerHour, _pullFundsScenario._wad * RAY));
    vm.assume(_enoughFunds(_pullFundsScenario));
    vm.assume(_notBelowPullFundsMinThreshold(_pullFundsScenario));
    _notOverflowExpensesAccumulator(_pullFundsScenario);
  }

  modifier happyPathAllowancePerHourNotZero(PullFundsScenario memory _pullFundsScenario) {
    _assumeHappyPathAllowancePerHourNotZero(_pullFundsScenario);
    _mockValues({_pullFundsScenario: _pullFundsScenario, _safeEngineDebtBalance: 0});
    vm.prank(user);
    _;
  }

  modifier happyPathAllowancePerHourZero(PullFundsScenario memory _pullFundsScenario) {
    _assumeHappyPathAllowancePerHourZero(_pullFundsScenario);
    _pullFundsScenario._allowancePerHour = 0;
    _mockValues({_pullFundsScenario: _pullFundsScenario, _safeEngineDebtBalance: 0});
    vm.prank(user);
    _;
  }

  function test_Set_PulledPerHour(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourNotZero(_pullFundsScenario)
  {
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);

    assertEq(
      stabilityFeeTreasury.pulledPerHour(user, block.timestamp / HOUR),
      _pullFundsScenario._initialPulledPerHour + (_pullFundsScenario._wad * RAY)
    );
  }

  function test_Call_Internal_JoinAllCoins(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourNotZero(_pullFundsScenario)
  {
    expectEmitNoIndex();
    emit CalledJoinAllCoins();

    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Call_Internal_SettleDebt(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourNotZero(_pullFundsScenario)
  {
    expectEmitNoIndex();
    emit CalledSettleDebt();

    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Set_Allowance(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourNotZero(_pullFundsScenario)
  {
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);

    (uint256 _totalAllowance,) = stabilityFeeTreasury.allowance(user);

    assertEq(_totalAllowance, _pullFundsScenario._totalAllowance - _pullFundsScenario._wad * RAY);
  }

  function test_Set_ExpensesAccumulator(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourNotZero(_pullFundsScenario)
  {
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);

    assertEq(
      stabilityFeeTreasury.expensesAccumulator(),
      _pullFundsScenario._initialExpensesAccumulator + _pullFundsScenario._wad * RAY
    );
  }

  function test_Call_TransferInternalCoins(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourNotZero(_pullFundsScenario)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        _pullFundsScenario._dstAccount,
        _pullFundsScenario._wad * RAY
      )
    );

    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Emit_PullFunds(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourNotZero(_pullFundsScenario)
  {
    vm.expectEmit(true, false, false, true);
    emit PullFunds(
      user,
      _pullFundsScenario._dstAccount,
      _pullFundsScenario._wad * RAY,
      _pullFundsScenario._initialExpensesAccumulator + _pullFundsScenario._wad * RAY
    );

    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Emit_PullFunds_AllowancePerHourZero(PullFundsScenario memory _pullFundsScenario)
    public
    happyPathAllowancePerHourZero(_pullFundsScenario)
  {
    vm.expectEmit(true, false, false, true);
    emit PullFunds(
      user,
      _pullFundsScenario._dstAccount,
      _pullFundsScenario._wad * RAY,
      _pullFundsScenario._initialExpensesAccumulator + _pullFundsScenario._wad * RAY
    );

    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function testFail_Emit_PullFunds_DstAccIsStabilityFeeTreasury() public {
    uint256 _wad = 1;
    vm.expectEmit(true, false, false, true);
    emit PullFunds(user, address(stabilityFeeTreasury), 1 * RAY, _wad * RAY);

    stabilityFeeTreasury.pullFunds(address(stabilityFeeTreasury), _wad);
  }

  function test_Revert_NotAllowed(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(!_allowed(_pullFundsScenario));
    _mockValues(_pullFundsScenario, 0);

    vm.expectRevert(bytes('StabilityFeeTreasury/not-allowed'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Revert_NullDst(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    _pullFundsScenario._dstAccount = address(0);

    _mockValues(_pullFundsScenario, 0);
    vm.expectRevert(bytes('StabilityFeeTreasury/null-dst'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Revert_DstIsAccounting(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));

    _pullFundsScenario._dstAccount = address(mockExtraSurplusReceiver);

    _mockValues(_pullFundsScenario, 0);
    vm.expectRevert(bytes('StabilityFeeTreasury/dst-cannot-be-accounting'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Revert_NullTransferAmount(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));

    _pullFundsScenario._wad = 0;

    _mockValues(_pullFundsScenario, 0);
    vm.expectRevert(bytes('StabilityFeeTreasury/null-transfer-amount'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Revert_PerHourLimitExceeded(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmmount(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(!_notPerHourLimitExceeded(_pullFundsScenario));

    _mockValues(_pullFundsScenario, 0);
    vm.expectRevert(bytes('StabilityFeeTreasury/per-block-limit-exceeded'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Revert_BadDebt(PullFundsScenario memory _pullFundsScenario, uint256 _debt) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmmount(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));
    vm.assume(_debt > 0);

    _mockValues(_pullFundsScenario, _debt);
    vm.expectRevert(bytes('StabilityFeeTreasury/outstanding-bad-debt'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Revert_NotEnoguhFunds(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmmount(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));
    vm.assume(!_enoughFunds(_pullFundsScenario));

    _mockValues(_pullFundsScenario, 0);
    vm.expectRevert(bytes('StabilityFeeTreasury/not-enough-funds'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }

  function test_Revert_BelowPullFundsMinThreshold(PullFundsScenario memory _pullFundsScenario) public {
    vm.assume(_notStabilityFeeTreasuryDstAcc(_pullFundsScenario));
    vm.assume(_allowed(_pullFundsScenario));
    vm.assume(_notNullDstAcc(_pullFundsScenario));
    vm.assume(_notAccountingDstAcc(_pullFundsScenario));
    vm.assume(_notNullTransferAmmount(_pullFundsScenario));
    vm.assume(_allowancePerHourNotZero(_pullFundsScenario));
    vm.assume(_notPerHourLimitExceeded(_pullFundsScenario));
    vm.assume(_enoughFunds(_pullFundsScenario));
    vm.assume(!_notBelowPullFundsMinThreshold(_pullFundsScenario));

    _mockValues(_pullFundsScenario, 0);
    vm.expectRevert(bytes('StabilityFeeTreasury/below-pullFunds-min-threshold'));

    vm.prank(user);
    stabilityFeeTreasury.pullFunds(_pullFundsScenario._dstAccount, _pullFundsScenario._wad);
  }
}

contract Unit_StabilityFeeTreasury_TransferSurplusFunds is Base {
  event TransferSurplusFunds(address _extraSurplusReceiver, uint256 _fundsToTransfer);

  function setUp() public virtual override {
    super.setUp();

    vm.prank(deployer);
    stabilityFeeTreasury =
    new StabilityFeeTreasuryForInternalCallsTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));
  }

  struct TransferSurplusFundsScenario {
    uint256 _initialExpensesAccumulator;
    uint256 _initialAccumulatorTag;
    uint256 _treasuryCapacity;
    uint256 _expensesMultiplier;
    uint256 _minimumFundsRequired;
    uint256 _coinBalance;
  }

  function _mockValues(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario,
    uint256 _debtBalance
  ) internal {
    _mockTreasuryCapacity(_transferSurplusFundsScenario._treasuryCapacity);
    _mockExpensesMultiplier(_transferSurplusFundsScenario._expensesMultiplier);
    _mockExpensesAccumulator(_transferSurplusFundsScenario._initialExpensesAccumulator);
    _mockAccumulatorTag(_transferSurplusFundsScenario._initialAccumulatorTag);
    _mockSafeEngineDebtBalance(_debtBalance);
    _mockSafeEngineCoinBalance(_transferSurplusFundsScenario._coinBalance);
    _mockMinimumFundsRequired(_transferSurplusFundsScenario._minimumFundsRequired);
  }

  function _notUnderflowExpenesAccumulator(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    internal
    pure
  {
    // not underflow expensesAccumulator
    vm.assume(
      _transferSurplusFundsScenario._initialExpensesAccumulator >= _transferSurplusFundsScenario._initialAccumulatorTag
    );
  }

  function _enoughTreasuryCapacity(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario,
    uint256 _latestExpenses
  ) internal pure returns (bool) {
    vm.assume(notOverflowMul(_transferSurplusFundsScenario._expensesMultiplier, _latestExpenses));

    // enough treasure capacity
    return _transferSurplusFundsScenario._treasuryCapacity
      > _transferSurplusFundsScenario._expensesMultiplier * _latestExpenses / HUNDRED;
  }

  function _keepRemainingFunds(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario,
    uint256 _latestExpenses
  ) internal pure returns (bool) {
    return _transferSurplusFundsScenario._minimumFundsRequired
      < _transferSurplusFundsScenario._expensesMultiplier * _latestExpenses / HUNDRED;
  }

  function _enoughCoinBalance(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario,
    uint256 _remainingFunds
  ) internal pure returns (bool) {
    return _transferSurplusFundsScenario._coinBalance > _remainingFunds;
  }

  function _assumeHappyPathEnoughTreasureCapacity(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    internal
    pure
  {
    _notUnderflowExpenesAccumulator(_transferSurplusFundsScenario);
    uint256 _latestExpenses =
      _transferSurplusFundsScenario._initialExpensesAccumulator - _transferSurplusFundsScenario._initialAccumulatorTag;
    vm.assume(_enoughTreasuryCapacity(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(_keepRemainingFunds(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(_enoughCoinBalance(_transferSurplusFundsScenario, _transferSurplusFundsScenario._treasuryCapacity));
  }

  function _assumeHappyPathEnoughTreasureCapacityRemainingFundsMinFundsRequired(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) internal pure {
    _notUnderflowExpenesAccumulator(_transferSurplusFundsScenario);
    uint256 _latestExpenses =
      _transferSurplusFundsScenario._initialExpensesAccumulator - _transferSurplusFundsScenario._initialAccumulatorTag;
    vm.assume(_enoughTreasuryCapacity(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(!_keepRemainingFunds(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(_enoughCoinBalance(_transferSurplusFundsScenario, _transferSurplusFundsScenario._minimumFundsRequired));
  }

  function _assumeHappyPathNotEnoughTreasureCapacity(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    internal
    pure
  {
    _notUnderflowExpenesAccumulator(_transferSurplusFundsScenario);
    uint256 _latestExpenses =
      _transferSurplusFundsScenario._initialExpensesAccumulator - _transferSurplusFundsScenario._initialAccumulatorTag;
    vm.assume(!_enoughTreasuryCapacity(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(!_keepRemainingFunds(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(_enoughCoinBalance(_transferSurplusFundsScenario, _transferSurplusFundsScenario._minimumFundsRequired));
  }

  function _assumeHappyPathNotEnoughTreasureCapacityKeepRemainingFunds(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) internal pure {
    _notUnderflowExpenesAccumulator(_transferSurplusFundsScenario);
    uint256 _latestExpenses =
      _transferSurplusFundsScenario._initialExpensesAccumulator - _transferSurplusFundsScenario._initialAccumulatorTag;
    vm.assume(!_enoughTreasuryCapacity(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(_keepRemainingFunds(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(
      _enoughCoinBalance(
        _transferSurplusFundsScenario, _transferSurplusFundsScenario._expensesMultiplier * _latestExpenses / HUNDRED
      )
    );
  }

  function _assumeHappyPathNotEnoughTreasureCapacityNotEnoughCoinBalance(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) internal pure {
    _notUnderflowExpenesAccumulator(_transferSurplusFundsScenario);
    uint256 _latestExpenses =
      _transferSurplusFundsScenario._initialExpensesAccumulator - _transferSurplusFundsScenario._initialAccumulatorTag;
    vm.assume(!_enoughTreasuryCapacity(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(!_keepRemainingFunds(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(!_enoughCoinBalance(_transferSurplusFundsScenario, _transferSurplusFundsScenario._minimumFundsRequired));
  }

  function _assumeHappyPathEnoughTreasureCapacityNotEnoughCoinBalance(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) internal pure {
    _notUnderflowExpenesAccumulator(_transferSurplusFundsScenario);
    uint256 _latestExpenses =
      _transferSurplusFundsScenario._initialExpensesAccumulator - _transferSurplusFundsScenario._initialAccumulatorTag;
    vm.assume(_enoughTreasuryCapacity(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(_keepRemainingFunds(_transferSurplusFundsScenario, _latestExpenses));
    vm.assume(!_enoughCoinBalance(_transferSurplusFundsScenario, _transferSurplusFundsScenario._treasuryCapacity));
  }

  modifier happyPathEnoughTreasureCapacity(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) {
    _assumeHappyPathEnoughTreasureCapacity(_transferSurplusFundsScenario);
    _mockValues(_transferSurplusFundsScenario, 0);
    _;
  }

  modifier happyPathEnoughTreasureCapacityNotEnoughCoinBalance(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) {
    _assumeHappyPathEnoughTreasureCapacityNotEnoughCoinBalance(_transferSurplusFundsScenario);
    _mockValues(_transferSurplusFundsScenario, 0);
    _;
  }

  modifier happyPathNotEnoughTreasureCapacity(TransferSurplusFundsScenario memory _transferSurplusFundsScenario) {
    _assumeHappyPathNotEnoughTreasureCapacity(_transferSurplusFundsScenario);
    _mockValues(_transferSurplusFundsScenario, 0);
    _;
  }

  modifier happyPathNotEnoughTreasureCapacityNotEnoughCoinBalance(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) {
    _assumeHappyPathNotEnoughTreasureCapacityNotEnoughCoinBalance(_transferSurplusFundsScenario);
    _mockValues(_transferSurplusFundsScenario, 0);
    _;
  }

  modifier happyPathEnoughTreasureCapacityRemainingFundsMinFundsRequired(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) {
    _assumeHappyPathEnoughTreasureCapacityRemainingFundsMinFundsRequired(_transferSurplusFundsScenario);
    _mockValues(_transferSurplusFundsScenario, 0);
    _;
  }

  modifier happyPathNotEnoughTreasureCapacityKeepRemainingFunds(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) {
    _assumeHappyPathNotEnoughTreasureCapacityKeepRemainingFunds(_transferSurplusFundsScenario);
    _mockValues(_transferSurplusFundsScenario, 0);
    _;
  }

  function test_Set_AccumulatorTag(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPathEnoughTreasureCapacity(_transferSurplusFundsScenario)
  {
    stabilityFeeTreasury.transferSurplusFunds();

    assertEq(stabilityFeeTreasury.accumulatorTag(), _transferSurplusFundsScenario._initialExpensesAccumulator);
  }

  function test_Set_AccumulatorTag_NotEnoughTreasureCapacity(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacity(_transferSurplusFundsScenario) {
    stabilityFeeTreasury.transferSurplusFunds();

    assertEq(stabilityFeeTreasury.accumulatorTag(), _transferSurplusFundsScenario._initialExpensesAccumulator);
  }

  function test_Set_LatestSurplusTransferTime(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPathEnoughTreasureCapacity(_transferSurplusFundsScenario)
  {
    stabilityFeeTreasury.transferSurplusFunds();

    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
  }

  function test_Set_LatestSurplusTransferTime_NotEnoughTreasureCapacity(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacity(_transferSurplusFundsScenario) {
    stabilityFeeTreasury.transferSurplusFunds();

    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
  }

  function test_Call_Internal_JoinAllCoins(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPathEnoughTreasureCapacity(_transferSurplusFundsScenario)
  {
    expectEmitNoIndex();
    emit CalledJoinAllCoins();

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Call_Internal_JoinAllCoins_NotEnoughTreasureCapacity(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacity(_transferSurplusFundsScenario) {
    expectEmitNoIndex();
    emit CalledJoinAllCoins();

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Call_Internal_SettleDebt(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPathEnoughTreasureCapacity(_transferSurplusFundsScenario)
  {
    expectEmitNoIndex();
    emit CalledSettleDebt();

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Call_Internal_SettleDebt_NotEnoughTreasureCapacity(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacity(_transferSurplusFundsScenario) {
    expectEmitNoIndex();
    emit CalledSettleDebt();

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Call_SafeEngine_TransferInternalCoins(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPathEnoughTreasureCapacity(_transferSurplusFundsScenario)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._treasuryCapacity
      )
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Call_SafeEngine_TransferInternalCoins_NotEnoughTreasureCapacity(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacity(_transferSurplusFundsScenario) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._minimumFundsRequired
      )
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Emit_TransferSurplusFunds(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPathEnoughTreasureCapacity(_transferSurplusFundsScenario)
  {
    expectEmitNoIndex();
    emit TransferSurplusFunds(
      mockExtraSurplusReceiver,
      _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._treasuryCapacity
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Emit_TransferSurplusFunds_NotEnoughTreasureCapacity(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacity(_transferSurplusFundsScenario) {
    expectEmitNoIndex();
    emit TransferSurplusFunds(
      mockExtraSurplusReceiver,
      _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._minimumFundsRequired
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function testFail_Call_SafeEngine_TransferInternalCoins(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathEnoughTreasureCapacityNotEnoughCoinBalance(_transferSurplusFundsScenario) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._treasuryCapacity
      )
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function testFail_Emit_TransferSurplusFunds(TransferSurplusFundsScenario memory _transferSurplusFundsScenario)
    public
    happyPathEnoughTreasureCapacityNotEnoughCoinBalance(_transferSurplusFundsScenario)
  {
    expectEmitNoIndex();
    emit TransferSurplusFunds(
      mockExtraSurplusReceiver,
      _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._treasuryCapacity
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function testFail_SafeEngine_TransferInternalCoins_NotEnoughTreasureCapacity_NotEnoughBalance(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacityNotEnoughCoinBalance(_transferSurplusFundsScenario) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._treasuryCapacity
      )
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function testFail_Emit_TransferSurplusFunds_NotEnoughTreasureCapacity_NotEnoughBalance(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacityNotEnoughCoinBalance(_transferSurplusFundsScenario) {
    expectEmitNoIndex();
    emit TransferSurplusFunds(
      mockExtraSurplusReceiver,
      _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._treasuryCapacity
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Revert_TransferCoolDownNotPassed(uint256 _surplusDelay, uint256 _timePassed) public {
    vm.assume(_timePassed < _surplusDelay);
    vm.assume(notOverflowAdd(block.timestamp, _surplusDelay));
    vm.assume(notOverflowAdd(block.timestamp + _timePassed, _surplusDelay));

    _mockSurplusTransferDelay(_surplusDelay);
    _mockLatestSurplusTransferTime(block.timestamp + _timePassed);

    vm.warp(block.timestamp + _timePassed);
    vm.expectRevert(bytes('StabilityFeeTreasury/transfer-cooldown-not-passed'));

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function testFail_Emit_TransferSurplusFunds_CooldownElapsed(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario,
    uint256 _surplusDelay,
    uint256 _timePassed
  ) public happyPathEnoughTreasureCapacityNotEnoughCoinBalance(_transferSurplusFundsScenario) {
    vm.assume(_timePassed >= _surplusDelay);
    vm.assume(notOverflowAdd(block.timestamp, _timePassed));

    _mockSurplusTransferDelay(_surplusDelay);
    _mockLatestSurplusTransferTime(block.timestamp + _timePassed);

    expectEmitNoIndex();
    emit TransferSurplusFunds(
      mockExtraSurplusReceiver,
      _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._treasuryCapacity
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Revert_BadDebt(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario,
    uint256 _debtBalance
  ) public happyPathEnoughTreasureCapacity(_transferSurplusFundsScenario) {
    vm.assume(_debtBalance > 0);
    _mockSafeEngineDebtBalance(_debtBalance);
    vm.expectRevert(bytes('StabilityFeeTreasury/outstanding-bad-debt'));

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Call_SafeEngine_TransferInternalCoins_enoughTreasuryCapacityRemainingFundsMinFundsRequired(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathEnoughTreasureCapacityRemainingFundsMinFundsRequired(_transferSurplusFundsScenario) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        _transferSurplusFundsScenario._coinBalance - _transferSurplusFundsScenario._minimumFundsRequired
      )
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_Call_SafeEngine_TransferInternalCoins_NotEnoughTreasureCapacityKeepRemainingFunds(
    TransferSurplusFundsScenario memory _transferSurplusFundsScenario
  ) public happyPathNotEnoughTreasureCapacityKeepRemainingFunds(_transferSurplusFundsScenario) {
    uint256 _latestExpenses =
      _transferSurplusFundsScenario._initialExpensesAccumulator - _transferSurplusFundsScenario._initialAccumulatorTag;

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector,
        address(stabilityFeeTreasury),
        mockExtraSurplusReceiver,
        _transferSurplusFundsScenario._coinBalance
          - _transferSurplusFundsScenario._expensesMultiplier * _latestExpenses / HUNDRED
      )
    );

    stabilityFeeTreasury.transferSurplusFunds();
  }
}

//StabilityFeeTreasuryForTest

contract Unit_StabilityFeeTreasury_JoinAllCoins is Base {
  function setUp() public virtual override {
    super.setUp();

    vm.prank(deployer);
    stabilityFeeTreasury =
      new StabilityFeeTreasuryForTest(address(mockSafeEngine), mockExtraSurplusReceiver, address(mockCoinJoin));
  }

  function test_Call_SystemCoin_BalanceOf(uint256 _balance) public {
    vm.assume(_balance > 0);
    _mockSystemCoinsBalanceOf(_balance);

    vm.expectCall(
      address(mockSystemCoin), abi.encodeWithSelector(ISystemCoin.balanceOf.selector, address(stabilityFeeTreasury)), 2
    );

    StabilityFeeTreasuryForTest(address(stabilityFeeTreasury)).callJoinAllCoins();
  }

  function test_Call_CoinJoin_Join(uint256 _balance) public {
    vm.assume(_balance > 0);
    _mockSystemCoinsBalanceOf(_balance);

    vm.expectCall(
      address(mockCoinJoin), abi.encodeWithSelector(ICoinJoin.join.selector, address(stabilityFeeTreasury), _balance), 1
    );

    StabilityFeeTreasuryForTest(address(stabilityFeeTreasury)).callJoinAllCoins();
  }

  function test_Not_Call_SystemCoin_BalanceOf() public {
    _mockSystemCoinsBalanceOf(0);

    vm.expectCall(
      address(mockSystemCoin), abi.encodeWithSelector(ISystemCoin.balanceOf.selector, address(stabilityFeeTreasury)), 1
    );

    StabilityFeeTreasuryForTest(address(stabilityFeeTreasury)).callJoinAllCoins();
  }

  function test_Not_Call_CoinJoin_Join() public {
    _mockSystemCoinsBalanceOf(0);

    vm.expectCall(
      address(mockCoinJoin), abi.encodeWithSelector(ICoinJoin.join.selector, address(stabilityFeeTreasury), 0), 0
    );

    StabilityFeeTreasuryForTest(address(stabilityFeeTreasury)).callJoinAllCoins();
  }
}
