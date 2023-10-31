// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AccountingEngineForTest, IAccountingEngine} from '@test/mocks/AccountingEngineForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {ICommonSurplusAuctionHouse} from '@interfaces/ICommonSurplusAuctionHouse.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';
import {Math} from '@libraries/Math.sol';

import {DummySAFEEngine} from '@test/mocks/SAFEEngineForTest.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = newAddress();
  ISAFEEngine mockSafeEngine = ISAFEEngine(address(new DummySAFEEngine()));
  IDebtAuctionHouse mockDebtAuctionHouse = IDebtAuctionHouse(mockContract('mockDebtAuctionHouse'));
  IDebtAuctionHouse mockSurplusAuctionHouse = IDebtAuctionHouse(mockContract('mockSurplusAuctionHouse'));
  IAccountingEngine accountingEngine;

  IAccountingEngine.AccountingEngineParams accountingEngineParams = IAccountingEngine.AccountingEngineParams({
    surplusIsTransferred: 0,
    surplusDelay: 0,
    popDebtDelay: 0,
    disableCooldown: 0,
    surplusAmount: 0,
    surplusBuffer: 0,
    debtAuctionMintedTokens: 0,
    debtAuctionBidSize: 0
  });

  function setUp() public virtual {
    vm.startPrank(deployer);

    accountingEngine =
    new AccountingEngineForTest(address(mockSafeEngine), address(mockSurplusAuctionHouse), address(mockDebtAuctionHouse), accountingEngineParams);
    vm.stopPrank();
  }

  function _mockCoinBalance(uint256 _coinBalance) internal {
    DummySAFEEngine(address(mockSafeEngine)).mockCoinBalance(address(accountingEngine), _coinBalance);
  }

  function _mockDebtBalance(uint256 _debtBalance) internal {
    DummySAFEEngine(address(mockSafeEngine)).mockDebtBalance(address(accountingEngine), _debtBalance);
  }

  function _mockCoinAndDebtBalance(uint256 _coinBalance, uint256 _debtBalance) internal {
    _mockCoinBalance(_coinBalance);
    _mockDebtBalance(_debtBalance);
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    AccountingEngineForTest(address(accountingEngine)).setContractEnabled(_contractEnabled);
  }

  function _mockTotalQueuedDebt(uint256 _totalQueuedDebt) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.totalQueuedDebt.selector).checked_write(
      _totalQueuedDebt
    );
  }

  function _mockTotalOnAuctionDebt(uint256 _totalOnAuctionDebt) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.totalOnAuctionDebt.selector).checked_write(
      _totalOnAuctionDebt
    );
  }

  function _mockDebtStartAuction(uint256 _id) internal {
    IAccountingEngine.AccountingEngineParams memory _params = accountingEngine.params();
    _mockDebtStartAuction(_id, _params.debtAuctionMintedTokens, _params.debtAuctionBidSize);
  }

  function _mockDebtStartAuction(uint256 _id, uint256 _debtAuctionMintedTokens, uint256 _debtAuctionBidSize) internal {
    vm.mockCall(
      address(mockDebtAuctionHouse),
      abi.encodeWithSelector(
        IDebtAuctionHouse.startAuction.selector,
        address(accountingEngine),
        _debtAuctionMintedTokens,
        _debtAuctionBidSize
      ),
      abi.encode(_id)
    );
  }

  function _mockSurplusStartAuction(uint256 _id) internal {
    IAccountingEngine.AccountingEngineParams memory _params = accountingEngine.params();
    _mockSurplusStartAuction(_id, _params.surplusAmount);
  }

  function _mockSurplusStartAuction(uint256 _id, uint256 _amountToSell) internal {
    vm.mockCall(
      address(mockSurplusAuctionHouse),
      abi.encodeWithSelector(ICommonSurplusAuctionHouse.startAuction.selector, _amountToSell, 0),
      abi.encode(_id)
    );
  }

  function _mockSurplusAuctionHouse(address _surplusAuctionHouse) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusAuctionHouse.selector).checked_write(
      _surplusAuctionHouse
    );
  }

  function _mockPostSettlementSurplusDrain(address _postSettlementSurplusDrain) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.postSettlementSurplusDrain.selector).checked_write(
      _postSettlementSurplusDrain
    );
  }

  function _mockQueuedDebt(uint256 _debtBlock, uint256 _timestamp) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.debtQueue.selector).with_key(_timestamp)
      .checked_write(_debtBlock);
    _mockTotalQueuedDebt(accountingEngine.totalQueuedDebt() + _debtBlock);
  }

  function _mockExtraSurplusReceiver(address _extraSurplusReceiver) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.extraSurplusReceiver.selector).checked_write(
      _extraSurplusReceiver
    );
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
    vm.stopPrank();
  }

  function _mockLastSurplusTime(uint256 _lastTime) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.lastSurplusTime.selector).checked_write(_lastTime);
  }

  function _mockDisableTimestamp(uint256 _disableTimestamp) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.disableTimestamp.selector).checked_write(
      _disableTimestamp
    );
  }

  // --- Params ---

  function _mockSurplusIsTransferred(uint256 _surplusIsTransferred) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(0).checked_write(
      _surplusIsTransferred
    );
  }

  function _mockSurplusDelay(uint256 _surplusDelay) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(1).checked_write(
      _surplusDelay
    );
  }

  function _mockPopDebtDelay(uint256 _popDebtDelay) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(2).checked_write(
      _popDebtDelay
    );
  }

  function _mockDisableCooldown(uint256 _disableCooldown) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(3).checked_write(
      _disableCooldown
    );
  }

  function _mockSurplusAmount(uint256 _surplusAmount) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(4).checked_write(
      _surplusAmount
    );
  }

  function _mockSurplusBuffer(uint256 _surplusBuffer) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(5).checked_write(
      _surplusBuffer
    );
  }

  function _mockDebtAuctionMintedTokens(uint256 _debtAuctionMintedTokens) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(6).checked_write(
      _debtAuctionMintedTokens
    );
  }

  function _mockDebtAuctionBidSize(uint256 _debtAuctionBidSize) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.params.selector).depth(7).checked_write(
      _debtAuctionBidSize
    );
  }
}

contract Unit_AccountingEngine_Constructor is Base {
  function test_Set_Parameters() public {
    assertEq(address(accountingEngine.safeEngine()), address(mockSafeEngine));
    assertEq(address(accountingEngine.surplusAuctionHouse()), address(mockSurplusAuctionHouse));
    assertEq(address(accountingEngine.debtAuctionHouse()), address(mockDebtAuctionHouse));
  }

  function test_Set_AccountingEngineParams(IAccountingEngine.AccountingEngineParams memory _accountingEngineParams)
    public
  {
    accountingEngine =
    new AccountingEngineForTest(address(mockSafeEngine), address(mockSurplusAuctionHouse), address(mockDebtAuctionHouse), _accountingEngineParams);
    assertEq(abi.encode(accountingEngine.params()), abi.encode(_accountingEngineParams));
  }

  function test_Revert_NullSafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);
    new AccountingEngineForTest(address(0), address(mockSurplusAuctionHouse), address(mockDebtAuctionHouse), accountingEngineParams);
  }

  function test_Revert_NullSurplusAuctionHouse() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new AccountingEngineForTest(address(mockSafeEngine), address(0), address(mockDebtAuctionHouse), accountingEngineParams);
  }

  function test_Revert_NullDebtAuctionHouse() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new AccountingEngineForTest(address(mockSafeEngine), address(mockSurplusAuctionHouse), address(0), accountingEngineParams);
  }
}

contract Unit_AccountingEngine_ModifyParameters is Base {
  function test_ModifyParameters(IAccountingEngine.AccountingEngineParams memory _fuzz) public authorized {
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(_fuzz.surplusIsTransferred));
    accountingEngine.modifyParameters('surplusDelay', abi.encode(_fuzz.surplusDelay));
    accountingEngine.modifyParameters('popDebtDelay', abi.encode(_fuzz.popDebtDelay));
    accountingEngine.modifyParameters('disableCooldown', abi.encode(_fuzz.disableCooldown));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(_fuzz.surplusAmount));
    accountingEngine.modifyParameters('surplusBuffer', abi.encode(_fuzz.surplusBuffer));
    accountingEngine.modifyParameters('debtAuctionMintedTokens', abi.encode(_fuzz.debtAuctionMintedTokens));
    accountingEngine.modifyParameters('debtAuctionBidSize', abi.encode(_fuzz.debtAuctionBidSize));

    IAccountingEngine.AccountingEngineParams memory _params = accountingEngine.params();

    assertEq(abi.encode(_fuzz), abi.encode(_params));
  }

  function test_ModifyParameters_SurplusAuctionHouse(address _surplusAuctionHouse)
    public
    authorized
    mockAsContract(_surplusAuctionHouse)
  {
    address _previousSurplusAuctionHouse = address(accountingEngine.surplusAuctionHouse());
    if (_previousSurplusAuctionHouse != address(0)) {
      vm.expectCall(
        address(mockSafeEngine),
        abi.encodeWithSelector(ISAFEEngine.denySAFEModification.selector, _previousSurplusAuctionHouse)
      );
    }
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.approveSAFEModification.selector, _surplusAuctionHouse)
    );

    accountingEngine.modifyParameters('surplusAuctionHouse', abi.encode(_surplusAuctionHouse));

    assertEq(_surplusAuctionHouse, address(accountingEngine.surplusAuctionHouse()));
  }

  function test_ModifyParameters_DebtAuctionHouse(address _debtAuctionHouse)
    public
    authorized
    mockAsContract(_debtAuctionHouse)
  {
    accountingEngine.modifyParameters('debtAuctionHouse', abi.encode(_debtAuctionHouse));

    assertEq(_debtAuctionHouse, address(accountingEngine.debtAuctionHouse()));
  }

  function test_ModifyParameters_PostSettlementSurplusDrain(address _postSettlementSurplusDrain) public authorized {
    accountingEngine.modifyParameters('postSettlementSurplusDrain', abi.encode(_postSettlementSurplusDrain));

    assertEq(_postSettlementSurplusDrain, address(accountingEngine.postSettlementSurplusDrain()));
  }

  function test_ModifyParameters_ExtraSurplusReceiver(address _extraSurplusReceiver) public authorized {
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(_extraSurplusReceiver));

    assertEq(_extraSurplusReceiver, address(accountingEngine.extraSurplusReceiver()));
  }

  function test_Revert_ModifyParameters_UnrecognizedParam() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    accountingEngine.modifyParameters('unrecognizedParam', abi.encode(0));
  }
}

contract Unit_AccountingEngine_UnqueuedUnauctionedDebt is Base {
  function _mockValues(uint256 _debtBalance, uint256 _totalQueuedDebt, uint256 _totalOnAuctionDebt) internal {
    _mockDebtBalance(_debtBalance);
    _mockTotalQueuedDebt(_totalQueuedDebt);
    _mockTotalOnAuctionDebt(_totalOnAuctionDebt);
  }

  function test_Return_UnqueuedUnauctionedDebt(
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    vm.assume(notOverflowAdd(_debtBalance, _totalQueuedDebt, _totalOnAuctionDebt));
    vm.assume(_debtBalance >= _totalQueuedDebt + _totalOnAuctionDebt);
    uint256 _unqueuedUnauctionedDebt = _debtBalance - _totalQueuedDebt - _totalOnAuctionDebt;
    _mockValues(_debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);

    assertEq(accountingEngine.unqueuedUnauctionedDebt(), _unqueuedUnauctionedDebt);
  }
}

contract Unit_AccountingEngine_PushDebtToQueue is Base {
  event PushDebtToQueue(uint256 indexed _blockTimestamp, uint256 _debtAmount);

  function _assumeHappyPath(uint256 _a, uint256 _b) internal pure {
    vm.assume(notOverflowAdd(_a, _b));
  }

  function _pushDebtQueueTwice(uint256 _debtBlock1, uint256 _debtBlock2, uint256 _timeElapsed) internal {
    accountingEngine.pushDebtToQueue(_debtBlock1);
    if (_timeElapsed > 0) vm.warp(block.timestamp + _timeElapsed);
    accountingEngine.pushDebtToQueue(_debtBlock2);
  }

  function test_Set_DebtQueue(uint256 _debtBlock) public authorized {
    accountingEngine.pushDebtToQueue(_debtBlock);

    assertEq(accountingEngine.debtQueue(block.timestamp), _debtBlock);
  }

  function test_Set_TotalQueuedDebt(uint256 _debtBlock, uint256 _totalQueuedDebt) public authorized {
    _assumeHappyPath(_debtBlock, _totalQueuedDebt);
    _mockTotalQueuedDebt(_totalQueuedDebt);
    uint256 _totalQueueDebt = accountingEngine.totalQueuedDebt() + _debtBlock;

    accountingEngine.pushDebtToQueue(_debtBlock);

    assertEq(accountingEngine.totalQueuedDebt(), _totalQueueDebt);
  }

  function test_Emit_PushDebtToQueue(uint256 _debtBlock, uint256 _totalQueuedDebt) public authorized {
    _assumeHappyPath(_debtBlock, _totalQueuedDebt);
    _mockTotalQueuedDebt(_totalQueuedDebt);

    vm.expectEmit();
    emit PushDebtToQueue(block.timestamp, _debtBlock);

    accountingEngine.pushDebtToQueue(_debtBlock);
  }

  function test_Set_DebtQueue_Addition(uint256 _debtBlock1, uint256 _debtBlock2) public authorized {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    _pushDebtQueueTwice(_debtBlock1, _debtBlock2, 0);

    assertEq(accountingEngine.debtQueue(block.timestamp), _debtBlock1 + _debtBlock2);
  }

  function test_Set_TotalQueuedDebt_Addition(uint256 _debtBlock1, uint256 _debtBlock2) public authorized {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    _pushDebtQueueTwice(_debtBlock1, _debtBlock2, 0);

    assertEq(accountingEngine.totalQueuedDebt(), _debtBlock1 + _debtBlock2);
  }

  function test_Set_DebtQueue_FirstAddition(uint256 _debtBlock1, uint256 _debtBlock2) public authorized {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    _pushDebtQueueTwice(_debtBlock1, _debtBlock2, 1);

    assertEq(accountingEngine.debtQueue(block.timestamp - 1), _debtBlock1);
  }

  function test_Set_DebtQueue_SecondAddition(uint256 _debtBlock1, uint256 _debtBlock2) public authorized {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    _pushDebtQueueTwice(_debtBlock1, _debtBlock2, 1);

    assertEq(accountingEngine.debtQueue(block.timestamp), _debtBlock2);
  }

  function test_Set_TotalQueuedDebt_LatterAddition(uint256 _debtBlock1, uint256 _debtBlock2) public authorized {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    _pushDebtQueueTwice(_debtBlock1, _debtBlock2, 1);

    assertEq(accountingEngine.totalQueuedDebt(), _debtBlock1 + _debtBlock2);
  }

  function test_Revert_NotAuthorized(uint256 _debtBlock) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    accountingEngine.pushDebtToQueue(_debtBlock);
  }
}

contract Unit_AccountingEngine_PopDebtFromQueue is Base {
  event PopDebtFromQueue(uint256 indexed _timestamp, uint256 _debtAmount);

  function _assumeHappyPath(uint256 _a, uint256 _b) internal pure {
    vm.assume(_a > 0 && _b > 0);
    vm.assume(notOverflowAdd(_a, _b));
  }

  function _mockTwoQueuedDebts(uint256 _debtBlock1, uint256 _debtBlock2, uint256 _timeElapsed) internal {
    _mockQueuedDebt(_debtBlock1, block.timestamp);
    if (_timeElapsed > 0) vm.warp(block.timestamp + _timeElapsed);
    _mockQueuedDebt(_debtBlock2, block.timestamp);
  }

  function test_Set_DebtQueue(uint256 _debtBlock) public {
    vm.assume(_debtBlock > 0);

    _mockQueuedDebt(_debtBlock, block.timestamp);
    accountingEngine.popDebtFromQueue(block.timestamp);

    assertEq(accountingEngine.debtQueue(block.timestamp), 0);
  }

  function test_Set_TotalQueuedDebt(uint256 _debtBlock) public {
    vm.assume(_debtBlock > 0);

    _mockQueuedDebt(_debtBlock, block.timestamp);
    accountingEngine.popDebtFromQueue(block.timestamp);

    assertEq(accountingEngine.totalQueuedDebt(), 0);
  }

  function test_Emit_PopDebtFromQueue(uint256 _debtBlock) public {
    vm.assume(_debtBlock > 0);

    _mockQueuedDebt(_debtBlock, block.timestamp);

    vm.expectEmit();
    emit PopDebtFromQueue(block.timestamp, _debtBlock);

    accountingEngine.popDebtFromQueue(block.timestamp);
  }

  function test_Set_FirstDebtQueue_Substraction(uint256 _debtBlock1, uint256 _debtBlock2) public {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    uint256 _debtBlock1Timestamp = block.timestamp;

    _mockTwoQueuedDebts(_debtBlock1, _debtBlock2, 1);
    accountingEngine.popDebtFromQueue(_debtBlock1Timestamp);

    assertEq(accountingEngine.debtQueue(_debtBlock1Timestamp), 0);
  }

  function test_Set_SecondDebtQueue_Substraction(uint256 _debtBlock1, uint256 _debtBlock2) public {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    uint256 _debtBlock1Timestamp = block.timestamp;

    _mockTwoQueuedDebts(_debtBlock1, _debtBlock2, 1);
    accountingEngine.popDebtFromQueue(_debtBlock1Timestamp);

    assertEq(accountingEngine.debtQueue(block.timestamp), _debtBlock2);
  }

  function test_Set_TotalQueuedDebt_Substraction(uint256 _debtBlock1, uint256 _debtBlock2) public {
    _assumeHappyPath(_debtBlock1, _debtBlock2);
    uint256 _debtBlock1Timestamp = block.timestamp;

    _mockTwoQueuedDebts(_debtBlock1, _debtBlock2, 1);
    accountingEngine.popDebtFromQueue(_debtBlock1Timestamp);

    assertEq(accountingEngine.totalQueuedDebt(), _debtBlock2);
  }

  function test_Revert_PopDebtDelayNotPassed(uint256 _debtBlock, uint128 _popDebtDelay) public {
    vm.assume(_debtBlock > 0 && _popDebtDelay > 0);

    _mockPopDebtDelay(_popDebtDelay);
    uint256 _debtBlockTimestamp = block.timestamp;
    _mockQueuedDebt(_debtBlock, block.timestamp);
    vm.warp(block.timestamp + _popDebtDelay - 1);

    vm.expectRevert(IAccountingEngine.AccEng_PopDebtCooldown.selector);
    accountingEngine.popDebtFromQueue(_debtBlockTimestamp);
  }

  function test_Revert_DebtQueueIsEmpty() public {
    vm.expectRevert(IAccountingEngine.AccEng_NullAmount.selector);
    accountingEngine.popDebtFromQueue(block.timestamp);
  }
}

contract Unit_AccountingEngine_SettleDebt is Base {
  event SettleDebt(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance);

  struct SettleDebtScenario {
    uint256 rad;
    uint256 coinBalance;
    uint256 debtBalance;
  }

  function _assumeHappyPath(SettleDebtScenario memory _scenario) internal pure {
    vm.assume(_scenario.rad > 0 && _scenario.rad <= _scenario.coinBalance && _scenario.rad <= _scenario.debtBalance);
  }

  function test_Call_SAFEEngine_CoinBalance(SettleDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockCoinAndDebtBalance(_scenario.coinBalance, _scenario.debtBalance);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 1
    );

    accountingEngine.settleDebt(_scenario.rad);
  }

  function test_Call_SAFEEngine_SettleDebt(SettleDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockCoinAndDebtBalance(_scenario.coinBalance, _scenario.debtBalance);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _scenario.rad));

    accountingEngine.settleDebt(_scenario.rad);
  }

  function test_Emit_SettleDebt(SettleDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockCoinAndDebtBalance(_scenario.coinBalance, _scenario.debtBalance);

    vm.expectEmit();
    emit SettleDebt({
      _rad: _scenario.rad,
      _coinBalance: _scenario.coinBalance - _scenario.rad,
      _debtBalance: _scenario.debtBalance - _scenario.rad
    });

    accountingEngine.settleDebt(_scenario.rad);
  }

  function test_Revert_CoinBalanceIsLtRad(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) public {
    vm.assume(_rad > 0 && _rad > _coinBalance && _rad <= _debtBalance);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);

    vm.expectRevert(IAccountingEngine.AccEng_InsufficientSurplus.selector);

    accountingEngine.settleDebt(_rad);
  }

  function test_Revert_DebtBalanceIsLtRad(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) public {
    vm.assume(_rad > 0 && _rad <= _coinBalance && _rad > _debtBalance);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);

    vm.expectRevert(IAccountingEngine.AccEng_InsufficientDebt.selector);

    accountingEngine.settleDebt(_rad);
  }
}

contract Unit_AccountingEngine_CancelAuctionedDebtWithSurplus is Base {
  event CancelDebt(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance);

  struct CancelAuctionedDebtWithSurplusScenario {
    uint256 rad;
    uint256 totalOnAuctionDebt;
    uint256 coinBalance;
    uint256 debtBalance;
  }

  function _assumeHappyPath(CancelAuctionedDebtWithSurplusScenario memory _scenario) internal pure {
    vm.assume(_scenario.rad > 0);
    vm.assume(_scenario.rad <= _scenario.totalOnAuctionDebt);
    vm.assume(_scenario.rad <= _scenario.coinBalance);
    vm.assume(_scenario.rad <= _scenario.debtBalance);
  }

  function _mockValues(CancelAuctionedDebtWithSurplusScenario memory _scenario) internal {
    _mockTotalOnAuctionDebt(_scenario.totalOnAuctionDebt);
    _mockCoinAndDebtBalance(_scenario.coinBalance, _scenario.debtBalance);
  }

  function test_Call_SAFEEngine_CoinBalance(CancelAuctionedDebtWithSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 1
    );

    accountingEngine.cancelAuctionedDebtWithSurplus(_scenario.rad);
  }

  function test_Call_SAFEEngine_SettleDebt(CancelAuctionedDebtWithSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _scenario.rad));

    accountingEngine.cancelAuctionedDebtWithSurplus(_scenario.rad);
  }

  function test_Set_TotalOnAuctionDebt(CancelAuctionedDebtWithSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    accountingEngine.cancelAuctionedDebtWithSurplus(_scenario.rad);

    assertEq(accountingEngine.totalOnAuctionDebt(), _scenario.totalOnAuctionDebt - _scenario.rad);
  }

  function test_Emit_CancelAuctionedDebtWithSurplus(CancelAuctionedDebtWithSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectEmit();
    emit CancelDebt({
      _rad: _scenario.rad,
      _coinBalance: _scenario.coinBalance - _scenario.rad,
      _debtBalance: _scenario.debtBalance - _scenario.rad
    });

    accountingEngine.cancelAuctionedDebtWithSurplus(_scenario.rad);
  }

  function test_Revert_TotalAuctionOnDebtLtRad(CancelAuctionedDebtWithSurplusScenario memory _scenario) public {
    vm.assume(_scenario.rad <= _scenario.coinBalance);
    vm.assume(_scenario.rad > _scenario.totalOnAuctionDebt);
    _mockValues(_scenario);

    vm.expectRevert(IAccountingEngine.AccEng_InsufficientDebt.selector);
    accountingEngine.cancelAuctionedDebtWithSurplus(_scenario.rad);
  }

  function test_Revert_CoinBalanceLtRad(CancelAuctionedDebtWithSurplusScenario memory _scenario) public {
    vm.assume(
      _scenario.rad > 0 && _scenario.rad <= _scenario.totalOnAuctionDebt && _scenario.rad > _scenario.coinBalance
    );
    _mockTotalOnAuctionDebt(_scenario.totalOnAuctionDebt);
    _mockCoinBalance(_scenario.coinBalance);

    vm.expectRevert(IAccountingEngine.AccEng_InsufficientSurplus.selector);

    accountingEngine.cancelAuctionedDebtWithSurplus(_scenario.rad);
  }
}

contract Unit_AccountingEngine_AuctionDebt is Base {
  event AuctionDebt(uint256 indexed _id, uint256 _initialBid, uint256 _debtAuctioned);

  function setUp() public virtual override {
    super.setUp();

    _mockCoinAndDebtBalance(0, 0);
    _mockDebtAuctionBidSize(0);
    _mockTotalQueuedDebt(0);
    _mockTotalOnAuctionDebt(0);
    _mockDebtStartAuction(1, 0, 0);

    vm.prank(deployer);
  }

  struct AuctionDebtScenario {
    uint256 debtAuctionBidSize;
    uint256 debtBalance;
    uint256 totalQueuedDebt;
    uint256 totalOnAuctionDebt;
  }

  function _assumeHappyPath(AuctionDebtScenario memory _scenario) internal pure {
    vm.assume(_scenario.debtAuctionBidSize > 0);
    vm.assume(notOverflowAdd(_scenario.totalQueuedDebt, _scenario.totalOnAuctionDebt));
    vm.assume(
      _scenario.debtBalance >= _scenario.totalOnAuctionDebt + _scenario.totalQueuedDebt
        && _scenario.debtAuctionBidSize
          <= _scenario.debtBalance - _scenario.totalQueuedDebt - _scenario.totalOnAuctionDebt
    );
  }

  function _mockValues(AuctionDebtScenario memory _scenario, uint256 _debtStartAuctionId) internal {
    _mockDebtAuctionBidSize(_scenario.debtAuctionBidSize);
    _mockDebtBalance(_scenario.debtBalance);
    _mockTotalQueuedDebt(_scenario.totalQueuedDebt);
    _mockTotalOnAuctionDebt(_scenario.totalOnAuctionDebt);
    _mockDebtStartAuction(_debtStartAuctionId);
  }

  function test_Call_SAFEEngine_CoinBalance(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 1
    );

    accountingEngine.auctionDebt();
  }

  function test_Call_SAFEEngine_SettleDebt(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, mockSafeEngine.coinBalance(address(accountingEngine)))
    );

    accountingEngine.auctionDebt();
  }

  function test_Call_DebtAuctionHouse_StartAuction(
    AuctionDebtScenario memory _scenario,
    uint256 _debtAuctionMintedTokens
  ) public {
    _mockDebtAuctionMintedTokens(_debtAuctionMintedTokens);
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    vm.expectCall(
      address(mockDebtAuctionHouse),
      abi.encodeWithSelector(
        IDebtAuctionHouse.startAuction.selector,
        address(accountingEngine),
        _debtAuctionMintedTokens,
        _scenario.debtAuctionBidSize
      )
    );

    accountingEngine.auctionDebt();
  }

  function test_Set_TotalAuctionOnDebt(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    accountingEngine.auctionDebt();

    assertEq(accountingEngine.totalOnAuctionDebt(), _scenario.totalOnAuctionDebt + _scenario.debtAuctionBidSize);
  }

  function test_Emit_AuctionDebt(AuctionDebtScenario memory _scenario, uint256 _debtAuctionMintedTokens) public {
    _mockDebtAuctionMintedTokens(_debtAuctionMintedTokens);
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    vm.expectEmit();
    emit AuctionDebt(1, _debtAuctionMintedTokens, _scenario.debtAuctionBidSize);

    accountingEngine.auctionDebt();
  }

  function test_Revert_DebtAuctionBidSizeIsZero(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _scenario.debtAuctionBidSize = 0;
    _mockValues(_scenario, 1);

    vm.expectRevert(IAccountingEngine.AccEng_DebtAuctionDisabled.selector);

    accountingEngine.auctionDebt();
  }

  function test_Revert_DebtAuctionBidSizeGtUnqueuedUnauctionedDebt(AuctionDebtScenario memory _scenario) public {
    vm.assume(notOverflowAdd(_scenario.totalQueuedDebt, _scenario.totalOnAuctionDebt));
    vm.assume(
      _scenario.debtBalance > _scenario.totalQueuedDebt + _scenario.totalOnAuctionDebt
        && _scenario.debtAuctionBidSize > _scenario.debtBalance - _scenario.totalQueuedDebt - _scenario.totalOnAuctionDebt
    );
    _mockValues(_scenario, 1);

    vm.expectRevert(IAccountingEngine.AccEng_InsufficientDebt.selector);

    accountingEngine.auctionDebt();
  }
}

contract Unit_AccountingEngine_AuctionSurplus is Base {
  event AuctionSurplus(uint256 indexed _id, uint256 _initialBid, uint256 _surplusAuctioned);

  struct AuctionSurplusScenario {
    uint256 surplusAmount;
    uint256 surplusBuffer;
    uint256 coinBalance;
  }

  function setUp() public virtual override {
    super.setUp();

    _mockCoinAndDebtBalance(5, 0);
    uint256 _amountToSell = 1;
    _mockSurplusIsTransferred(0);
    _mockSurplusAmount(_amountToSell);
    _mockSurplusBuffer(0);
    _mockTotalQueuedDebt(0);
    _mockSurplusAuctionHouse(address(mockSurplusAuctionHouse));
    _mockSurplusStartAuction(1);
    _mockSurplusStartAuction(1, _amountToSell);
  }

  function _assumeHappyPath(AuctionSurplusScenario memory _scenario) internal pure {
    vm.assume(notOverflowAdd(_scenario.surplusAmount, _scenario.surplusBuffer));
    vm.assume(_scenario.coinBalance >= _scenario.surplusAmount + _scenario.surplusBuffer);
    vm.assume(_scenario.surplusAmount > 0);
  }

  function _mockValues(
    uint256 _surplusIsTransferred,
    uint256 _debtBalance,
    AuctionSurplusScenario memory _scenario
  ) internal {
    _mockSurplusIsTransferred(_surplusIsTransferred);
    _mockSurplusAmount(_scenario.surplusAmount);
    _mockSurplusBuffer(_scenario.surplusBuffer);
    _mockCoinAndDebtBalance(_scenario.coinBalance, _debtBalance);
    _mockSurplusStartAuction(1);
  }

  function test_Call_SAFEEngine_SettleDebt(AuctionSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(0, 0, _scenario);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, 0));

    accountingEngine.auctionSurplus();
  }

  function test_Call_SAFEEngine_DebtBalance(AuctionSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(0, 0, _scenario);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.debtBalance.selector, address(accountingEngine)), 1
    );

    accountingEngine.auctionSurplus();
  }

  function test_Call_SurplusAuctionHouse_StartAuction(AuctionSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(0, 0, _scenario);

    vm.expectCall(
      address(mockSurplusAuctionHouse),
      abi.encodeWithSelector(ICommonSurplusAuctionHouse.startAuction.selector, _scenario.surplusAmount, 0)
    );

    vm.warp(block.timestamp + 1);

    accountingEngine.auctionSurplus();

    assertEq(accountingEngine.lastSurplusTime(), block.timestamp);
  }

  function test_Set_LastSurplusTime(AuctionSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(0, 0, _scenario);

    vm.warp(block.timestamp + 1);
    accountingEngine.auctionSurplus();

    assertEq(accountingEngine.lastSurplusTime(), block.timestamp);
  }

  function test_Emit_AuctionSurplus(AuctionSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(0, 0, _scenario);

    vm.expectEmit();
    emit AuctionSurplus(1, 0, _scenario.surplusAmount);

    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusIsTransferredIs1() public {
    _mockSurplusIsTransferred(1);

    vm.expectRevert(IAccountingEngine.AccEng_SurplusAuctionDisabled.selector);
    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusAuctionAmountToSellIsZero() public {
    _mockSurplusAmount(0);

    vm.expectRevert(IAccountingEngine.AccEng_NullAmount.selector);

    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusAuctionDelayNotPassed(uint128 _surplusDelay, uint256 _timeElapsed) public {
    vm.assume(_timeElapsed < _surplusDelay);
    _mockSurplusDelay(_surplusDelay);
    _mockLastSurplusTime(block.timestamp);
    vm.warp(block.timestamp + _timeElapsed);

    vm.expectRevert(IAccountingEngine.AccEng_SurplusCooldown.selector);

    accountingEngine.auctionSurplus();
  }

  function test_Revert_InsufficientSurplus(AuctionSurplusScenario memory _scenario) public {
    vm.assume(notOverflowAdd(_scenario.surplusAmount, _scenario.surplusBuffer));
    vm.assume(_scenario.coinBalance < _scenario.surplusAmount + _scenario.surplusBuffer);
    vm.assume(_scenario.surplusAmount > 0);
    _mockValues(0, 0, _scenario);

    vm.expectRevert(IAccountingEngine.AccEng_InsufficientSurplus.selector);

    accountingEngine.auctionSurplus();
  }
}

contract Unit_AccountingEngine_TransferExtraSurplus is Base {
  address extraSurplusReceiver = newAddress();

  struct TransferSurplusScenario {
    uint256 surplusAmount;
    uint256 surplusBuffer;
    uint256 coinBalance;
    uint256 debtBalance;
    uint256 totalQueueDebt;
    uint256 totalOnAuctionDebt;
  }

  event TransferSurplus(address indexed _extraSurplusReceiver, uint256 _surplusTransferred);

  function setUp() public virtual override {
    super.setUp();

    _mockSurplusIsTransferred(1);
    _mockExtraSurplusReceiver(extraSurplusReceiver);
  }

  function _mockValues(TransferSurplusScenario memory _scenario) internal {
    _mockTotalQueuedDebt(_scenario.totalQueueDebt);
    _mockTotalOnAuctionDebt(_scenario.totalOnAuctionDebt);
    _mockSurplusAmount(_scenario.surplusAmount);
    _mockSurplusBuffer(_scenario.surplusBuffer);
    _mockCoinAndDebtBalance(_scenario.coinBalance, _scenario.debtBalance);
  }

  function _assumeHappyPath(TransferSurplusScenario memory _scenario) internal returns (uint256 _debtToSettle) {
    vm.assume(_scenario.debtBalance >= _scenario.totalQueueDebt);
    vm.assume(_scenario.debtBalance >= _scenario.totalOnAuctionDebt);
    vm.assume(notOverflowAdd(_scenario.totalQueueDebt, _scenario.totalOnAuctionDebt));
    vm.assume(_scenario.debtBalance >= _scenario.totalQueueDebt + _scenario.totalOnAuctionDebt);
    _debtToSettle = (_scenario.debtBalance - _scenario.totalQueueDebt) - _scenario.totalOnAuctionDebt;
    vm.assume(notOverflowAdd(_scenario.surplusAmount, _scenario.surplusBuffer, _scenario.debtBalance));
    vm.assume(_scenario.coinBalance >= _scenario.surplusAmount + _scenario.surplusBuffer + _scenario.debtBalance);
    vm.assume(_scenario.surplusAmount > 0);
    _mockValues(_scenario);
  }

  function test_Call_SAFEEngine_SettleDebt(TransferSurplusScenario memory _scenario) public {
    uint256 _debtToSettle = _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _debtToSettle));

    accountingEngine.transferExtraSurplus();
  }

  function test_Call_SAFEEngine_TransferInternalCoins(TransferSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector, address(accountingEngine), extraSurplusReceiver
      )
    );

    accountingEngine.transferExtraSurplus();
  }

  function test_Call_SAFEEngine_CoinBalance(TransferSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 1
    );

    accountingEngine.transferExtraSurplus();
  }

  function test_Set_LastSurplusTime(TransferSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    accountingEngine.transferExtraSurplus();

    assertEq(accountingEngine.lastSurplusTime(), block.timestamp);
  }

  function test_Emit_TransferSurplus(TransferSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectEmit();
    emit TransferSurplus(extraSurplusReceiver, _scenario.surplusAmount);

    accountingEngine.transferExtraSurplus();
  }

  function test_RevertIfExtraSurplusIsNot1(uint256 _surplusIsTransferred) public {
    vm.assume(_surplusIsTransferred != 1);

    _mockSurplusIsTransferred(_surplusIsTransferred);

    vm.expectRevert(IAccountingEngine.AccEng_SurplusTransferDisabled.selector);

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_ExtraSurplusReceiverIsZero() public {
    extraSurplusReceiver = address(0);
    _mockExtraSurplusReceiver(extraSurplusReceiver);

    vm.expectRevert(IAccountingEngine.AccEng_NullSurplusReceiver.selector);

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_SurplusTransferAmountIsZero() public {
    _mockSurplusAmount(0);

    vm.expectRevert(IAccountingEngine.AccEng_NullAmount.selector);
    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_TransferDelayNotPassed(uint128 _surplusDelay, uint128 _timeElapsed) public {
    vm.assume(_timeElapsed < _surplusDelay);
    _mockSurplusDelay(_surplusDelay);
    _mockLastSurplusTime(block.timestamp + _timeElapsed);
    _mockSurplusAmount(1);

    vm.warp(block.timestamp + _timeElapsed);
    vm.expectRevert(IAccountingEngine.AccEng_SurplusCooldown.selector);

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_SurplusIsInsufficient(TransferSurplusScenario memory _scenario) public {
    vm.assume(_scenario.debtBalance >= _scenario.totalQueueDebt);
    vm.assume(_scenario.debtBalance >= _scenario.totalOnAuctionDebt);
    vm.assume(notOverflowAdd(_scenario.totalQueueDebt, _scenario.totalOnAuctionDebt));
    vm.assume(_scenario.debtBalance >= _scenario.totalQueueDebt + _scenario.totalOnAuctionDebt);
    vm.assume(notOverflowAdd(_scenario.surplusAmount, _scenario.surplusBuffer, _scenario.debtBalance));
    vm.assume(_scenario.coinBalance < _scenario.surplusAmount + _scenario.surplusBuffer + _scenario.debtBalance);
    vm.assume(_scenario.surplusAmount > 0);

    _mockValues(_scenario);

    vm.expectRevert(IAccountingEngine.AccEng_InsufficientSurplus.selector);

    accountingEngine.transferExtraSurplus();
  }
}

contract Unit_AccountingEngine_TransferPostSettlementSurplus is Base {
  address postSettlementSurplusDrain;

  function setUp() public virtual override {
    super.setUp();
    postSettlementSurplusDrain = newAddress();
  }

  struct TransferPostSettlementSurplusScenario {
    uint256 coinBalance;
    uint256 debtBalance;
    uint256 timestamp;
    uint256 disableTimestamp;
    uint256 disableCooldown;
  }

  event TransferSurplus(address indexed _extraSurplusReceiver, uint256 _surplusTransferred);
  event SettleDebt(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance);

  function _assumeHappyPath(TransferPostSettlementSurplusScenario memory _scenario)
    internal
    pure
    returns (uint256 _debtToSettle)
  {
    vm.assume(notOverflowAdd(_scenario.disableTimestamp, _scenario.disableCooldown));
    vm.assume(_scenario.timestamp >= _scenario.disableTimestamp + _scenario.disableCooldown);
    return Math.min(_scenario.coinBalance, _scenario.debtBalance);
  }

  function _mockValues(TransferPostSettlementSurplusScenario memory _scenario) internal {
    _mockPostSettlementSurplusDrain(postSettlementSurplusDrain);
    _mockContractEnabled(false);

    _mockCoinAndDebtBalance(_scenario.coinBalance, _scenario.debtBalance);
    _mockDisableTimestamp(_scenario.disableTimestamp);
    _mockDisableCooldown(_scenario.disableCooldown);
    vm.warp(_scenario.timestamp);
  }

  function test_Call_SAFEEngine_CoinBalance(TransferPostSettlementSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, accountingEngine));

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Call_SAFEEngine_DebtBalance(TransferPostSettlementSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.debtBalance.selector, accountingEngine));

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Call_SAFEEngine_SettleDebt(TransferPostSettlementSurplusScenario memory _scenario) public {
    uint256 _debtToSettle = _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _debtToSettle));

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Call_SAFEEngine_TransferInternalCalls(TransferPostSettlementSurplusScenario memory _scenario) public {
    uint256 _debtToSettle = _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    uint256 _coinBalance = _scenario.coinBalance - _debtToSettle;
    vm.assume(_coinBalance > 0);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector, address(accountingEngine), postSettlementSurplusDrain, _coinBalance
      )
    );

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Not_Call_SAFEEngine_TransferInternalCalls(TransferPostSettlementSurplusScenario memory _scenario)
    public
  {
    uint256 _debtToSettle = _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    uint256 _coinBalance = _scenario.coinBalance - _debtToSettle;
    vm.assume(_coinBalance == 0);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector, address(accountingEngine), postSettlementSurplusDrain, _coinBalance
      ),
      0
    );

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Emit_SettleDebt(TransferPostSettlementSurplusScenario memory _scenario) public {
    uint256 _debtToSettle = _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    uint256 _coinBalance = _scenario.coinBalance - _debtToSettle;

    if (_coinBalance > 0) {
      vm.expectEmit();
      emit SettleDebt({_rad: _debtToSettle, _coinBalance: _coinBalance, _debtBalance: 0});
    }

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Emit_TransferSurplus(TransferPostSettlementSurplusScenario memory _scenario) public {
    uint256 _debtToSettle = _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    uint256 _coinBalance = _scenario.coinBalance - _debtToSettle;

    if (_coinBalance > 0) {
      vm.expectEmit();
      emit TransferSurplus(postSettlementSurplusDrain, _coinBalance);
    }

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Revert_PostSettlement_NullReceiver(TransferPostSettlementSurplusScenario memory _scenario) public {
    vm.assume(notOverflowAdd(_scenario.disableTimestamp, _scenario.disableCooldown));
    vm.assume(_scenario.timestamp < _scenario.disableTimestamp + _scenario.disableCooldown);
    _mockValues(_scenario);
    _mockPostSettlementSurplusDrain(address(0));
    vm.expectRevert(IAccountingEngine.AccEng_NullSurplusReceiver.selector);

    accountingEngine.transferPostSettlementSurplus();
  }

  function test_Revert_PostSettlementCooldown(TransferPostSettlementSurplusScenario memory _scenario) public {
    vm.assume(notOverflowAdd(_scenario.disableTimestamp, _scenario.disableCooldown));
    vm.assume(_scenario.timestamp < _scenario.disableTimestamp + _scenario.disableCooldown);
    _mockValues(_scenario);

    vm.expectRevert(IAccountingEngine.AccEng_PostSettlementCooldown.selector);

    accountingEngine.transferPostSettlementSurplus();
  }
}
