// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {SettlementSurplusAuctioneer} from '@contracts/SettlementSurplusAuctioneer.sol';
import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {IProtocolTokenAuthority} from '@interfaces/external/IProtocolTokenAuthority.sol';
import {ISystemStakingPool} from '@interfaces/external/ISystemStakingPool.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = newAddress();
  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('mockSafeEngine'));
  IProtocolTokenAuthority mockProtocolTokenAuthority =
    IProtocolTokenAuthority(mockContract('mockProtocolTokenAuthority'));
  IDebtAuctionHouse mockDebtAuctionHouse = IDebtAuctionHouse(mockContract('mockDebtAuctionHouse'));
  IDebtAuctionHouse mockSurplusAuctionHouse = IDebtAuctionHouse(mockContract('mockSurplusAuctionHouse'));
  IAccountingEngine accountingEngine;
  ISystemStakingPool stakingPool = ISystemStakingPool(mockContract('system_staking_pool'));

  function setUp() public virtual {
    vm.startPrank(deployer);
    accountingEngine =
      new AccountingEngine(address(mockSafeEngine), address(mockSurplusAuctionHouse), address(mockDebtAuctionHouse));
    vm.stopPrank();
  }

  function _mockCoinBalance(uint256 _coinBalance) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)),
      abi.encode(_coinBalance)
    );
  }

  function _mockDebtBalance(uint256 _debtBalance) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.debtBalance.selector, address(accountingEngine)),
      abi.encode(_debtBalance)
    );
  }

  function _mockCoinAndDebtBalance(uint256 _coinBalance, uint256 _debtBalance) internal {
    _mockCoinBalance(_coinBalance);
    _mockDebtBalance(_debtBalance);
  }

  function _mockDebtAuctionBidSize(uint256 _debtAuctionBidSize) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.debtAuctionBidSize.selector).checked_write(
      _debtAuctionBidSize
    );
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

  function _mockProtocolTokenDebtAuctionHouse(address _token) internal {
    vm.mockCall(
      address(mockDebtAuctionHouse),
      abi.encodeWithSelector(IDebtAuctionHouse.protocolToken.selector),
      abi.encode(_token)
    );
  }

  function _mockProtocolTokenAuthorityAuthorizationDebtAuctionHouse(int256 _authorized) internal {
    vm.mockCall(
      address(mockProtocolTokenAuthority),
      abi.encodeWithSelector(IProtocolTokenAuthority.authorizedAccounts.selector, address(mockDebtAuctionHouse)),
      abi.encode(_authorized)
    );
  }

  function _mockProtocolTokenSurplusAuctionHouse(address _token) internal {
    vm.mockCall(
      address(mockSurplusAuctionHouse),
      abi.encodeWithSelector(ISurplusAuctionHouse.protocolToken.selector),
      abi.encode(_token)
    );
  }

  function _mockDebtStartAuction(uint256 _id) internal {
    _mockDebtStartAuction(_id, accountingEngine.initialDebtAuctionMintedTokens(), accountingEngine.debtAuctionBidSize());
  }

  function _mockDebtStartAuction(
    uint256 _id,
    uint256 _initialDebtAuctionMintedTokens,
    uint256 _debtAuctionBidSize
  ) internal {
    vm.mockCall(
      address(mockDebtAuctionHouse),
      abi.encodeWithSelector(
        IDebtAuctionHouse.startAuction.selector,
        address(accountingEngine),
        _initialDebtAuctionMintedTokens,
        _debtAuctionBidSize
      ),
      abi.encode(_id)
    );
  }

  function _mockSurplusStartAuction(uint256 _id) internal {
    _mockSurplusStartAuction(_id, accountingEngine.surplusAuctionAmountToSell());
  }

  function _mockSurplusStartAuction(uint256 _id, uint256 _amountToSell) internal {
    vm.mockCall(
      address(mockSurplusAuctionHouse),
      abi.encodeWithSelector(ISurplusAuctionHouse.startAuction.selector, _amountToSell, 0),
      abi.encode(_id)
    );
  }

  function _mockSystemStakingPool(bool canPrint) internal {
    vm.mockCall(
      address(stakingPool),
      abi.encodeWithSelector(ISystemStakingPool.canPrintProtocolTokens.selector),
      abi.encode(canPrint)
    );
  }

  function _mockProtocolTokenAuthority(address _protocolTokenAuthority) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.protocolTokenAuthority.selector).checked_write(
      _protocolTokenAuthority
    );
  }

  function _mockExtraSurplusIsTransferred(uint256 _extraSurplusIsTransferred) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.extraSurplusIsTransferred.selector).checked_write(
      _extraSurplusIsTransferred
    );
  }

  function _mockSurplusAuctionAmountToSell(uint256 _surplusAuctionAmountToSell) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusAuctionAmountToSell.selector).checked_write(
      _surplusAuctionAmountToSell
    );
  }

  function _mockSurplusBuffer(uint256 _surplusBuffer) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusBuffer.selector).checked_write(
      _surplusBuffer
    );
  }

  function _mockSurplusAuctionHouse(address _surplusAuctionHouse) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusAuctionHouse.selector).checked_write(
      _surplusAuctionHouse
    );
  }

  function _mockSurplusTransferAmount(uint256 _surplusTransferAmount) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusTransferAmount.selector).checked_write(
      _surplusTransferAmount
    );
  }

  function _mockQueuedDebt(uint256 _debtBlock, uint256 _timestamp) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.debtQueue.selector).with_key(_timestamp)
      .checked_write(_debtBlock);
    _mockTotalQueuedDebt(accountingEngine.totalQueuedDebt() + _debtBlock);
  }

  function _mockLastSurplusAuctionTime(uint256 _lastTime) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.lastSurplusAuctionTime.selector).checked_write(
      _lastTime
    );
  }

  function _mockExtraSurplusReceiver(address _extraSurplusReceiver) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.extraSurplusReceiver.selector).checked_write(
      _extraSurplusReceiver
    );
  }

  function _mockPopDebtDelay(uint256 _popDebtDelay) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.popDebtDelay.selector).checked_write(_popDebtDelay);
  }

  function _mockSystemStakingPoolAddress() internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.systemStakingPool.selector).checked_write(
      address(stakingPool)
    );
  }

  function _mockSurplusTransferDelay(uint256 _surplusTransferDelay) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusTransferDelay.selector).checked_write(
      _surplusTransferDelay
    );
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
    vm.stopPrank();
  }

  function _mockSurplusAuctionDelay(uint256 _surplusAuctionDelay) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusAuctionDelay.selector).checked_write(
      _surplusAuctionDelay
    );
  }

  function _mockLastSurplusTransferTime(uint256 _lastTime) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.lastSurplusTransferTime.selector).checked_write(
      _lastTime
    );
  }
}

contract Unit_AccountingEngine_Constructor is Base {
  function test_Set_Parameters() public {
    assertEq(address(accountingEngine.safeEngine()), address(mockSafeEngine));
    assertEq(address(accountingEngine.surplusAuctionHouse()), address(mockSurplusAuctionHouse));
    assertEq(address(accountingEngine.debtAuctionHouse()), address(mockDebtAuctionHouse));
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
    vm.assume(notOverflow(_debtBalance, _totalQueuedDebt, _totalOnAuctionDebt));
    vm.assume(_debtBalance >= _totalQueuedDebt + _totalOnAuctionDebt);
    uint256 _unqueuedUnauctionedDebt = _debtBalance - _totalQueuedDebt - _totalOnAuctionDebt;
    _mockValues(_debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);

    assertEq(accountingEngine.unqueuedUnauctionedDebt(), _unqueuedUnauctionedDebt);
  }
}

contract Unit_AccountingEngine_PushDebtToQueue is Base {
  event PushDebtToQueue(uint256 indexed _timestamp, uint256 _debtQueueBlock, uint256 _totalQueuedDebt);

  function _assumeHappyPath(uint256 _a, uint256 _b) internal {
    vm.assume(notOverflow(_a, _b));
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

    vm.expectEmit(true, false, false, true);

    emit PushDebtToQueue(block.timestamp, _debtBlock, accountingEngine.totalQueuedDebt() + _debtBlock);

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
    vm.expectRevert(bytes('AccountingEngine/account-not-authorized'));

    accountingEngine.pushDebtToQueue(_debtBlock);
  }
}

contract Unit_AccountingEngine_PopDebtFromQueue is Base {
  event PopDebtFromQueue(uint256 indexed _timestamp, uint256 _debtQueueBlock, uint256 _totalQueuedDebt);

  function _assumeHappyPath(uint256 _a, uint256 _b) internal {
    vm.assume(_a > 0 && _b > 0);
    vm.assume(notOverflow(_a, _b));
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

  function test_Set_DebtPoppers(uint256 _debtBlock) public {
    vm.assume(_debtBlock > 0);
    address _debtPopper = newAddress();

    vm.startPrank(_debtPopper);
    _mockQueuedDebt(_debtBlock, block.timestamp);
    accountingEngine.popDebtFromQueue(block.timestamp);
    vm.stopPrank();

    assertEq(accountingEngine.debtPoppers(block.timestamp), _debtPopper);
  }

  function test_Emit_PopDebtFromQueue(uint256 _debtBlock) public {
    vm.assume(_debtBlock > 0);

    _mockQueuedDebt(_debtBlock, block.timestamp);

    vm.expectEmit(true, false, false, true);
    emit PopDebtFromQueue(block.timestamp, _debtBlock, 0);

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

    vm.expectRevert(bytes('AccountingEngine/pop-debt-delay-not-passed'));
    accountingEngine.popDebtFromQueue(_debtBlockTimestamp);
  }

  function test_Revert_DebtQueueIsEmpty() public {
    vm.expectRevert(bytes('AccountingEngine/null-debt-block'));
    accountingEngine.popDebtFromQueue(block.timestamp);
  }
}

contract Unit_AccountingEngine_SettleDebt is Base {
  event SettleDebt(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance);

  function _assumeHappyPath(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) internal {
    vm.assume(_rad > 0 && _rad <= _coinBalance && _rad <= _debtBalance);
  }

  function test_Call_SAFEEngine_CoinBalance(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) public {
    _assumeHappyPath(_rad, _coinBalance, _debtBalance);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine))
    );

    accountingEngine.settleDebt(_rad);
  }

  function test_Call_SAFEEngine_SettleDebt(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) public {
    _assumeHappyPath(_rad, _coinBalance, _debtBalance);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _rad));

    accountingEngine.settleDebt(_rad);
  }

  function test_Emits_SettleDebt(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) public {
    _assumeHappyPath(_rad, _coinBalance, _debtBalance);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);

    vm.expectEmit(true, false, false, true);
    emit SettleDebt(_rad, _coinBalance, _debtBalance);

    accountingEngine.settleDebt(_rad);
  }

  function test_Revert_CoinBalanceIsLtRad(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) public {
    vm.assume(_rad > 0 && _rad > _coinBalance && _rad <= _debtBalance);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);

    vm.expectRevert(bytes('AccountingEngine/insufficient-surplus'));

    accountingEngine.settleDebt(_rad);
  }

  function test_Revert_DebtBalanceIsLtRad(uint256 _rad, uint256 _coinBalance, uint256 _debtBalance) public {
    vm.assume(_rad > 0 && _rad <= _coinBalance && _rad > _debtBalance);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);

    vm.expectRevert(bytes('AccountingEngine/insufficient-debt'));

    accountingEngine.settleDebt(_rad);
  }
}

contract Unit_AccountingEngine_CancelAuctionedDebtWithSurplus is Base {
  event CancelAuctionedDebtWithSurplus(
    uint256 _rad, uint256 _totalOnAuctionDebt, uint256 _coinBalance, uint256 _debtBalance
  );

  function _assumeHappyPath(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) internal {
    vm.assume(_rad > 0 && _rad <= _totalBalance && _rad <= _debtBalance);
  }

  function _mockValues(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) internal {
    _mockTotalOnAuctionDebt(_totalBalance);
    _mockCoinAndDebtBalance(_rad, _debtBalance);
  }

  function test_Call_SAFEEngine_CoinBalance(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) public {
    _assumeHappyPath(_rad, _totalBalance, _debtBalance);
    _mockValues(_rad, _totalBalance, _debtBalance);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine))
    );

    accountingEngine.cancelAuctionedDebtWithSurplus(_rad);
  }

  function test_Call_SAFEEngine_SettleDebt(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) public {
    _assumeHappyPath(_rad, _totalBalance, _debtBalance);
    _mockValues(_rad, _totalBalance, _debtBalance);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, _rad));

    accountingEngine.cancelAuctionedDebtWithSurplus(_rad);
  }

  function test_Set_TotalOnAuctionDebt(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) public {
    vm.assume(_rad > 0 && _rad <= _totalBalance);
    _mockValues(_rad, _totalBalance, _debtBalance);

    accountingEngine.cancelAuctionedDebtWithSurplus(_rad);

    assertEq(accountingEngine.totalOnAuctionDebt(), _totalBalance - _rad);
  }

  function test_Emit_CancelAuctionedDebtWithSurplus(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) public {
    vm.assume(_rad > 0 && _rad <= _totalBalance);
    _mockValues(_rad, _totalBalance, _debtBalance);

    expectEmitNoIndex();
    emit CancelAuctionedDebtWithSurplus(_rad, _totalBalance - _rad, _rad, _debtBalance);

    accountingEngine.cancelAuctionedDebtWithSurplus(_rad);
  }

  function test_Revert_TotalAuctionOnDebtLtRad(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) public {
    vm.assume(_rad > 0 && _rad > _totalBalance);
    _mockValues(_rad, _totalBalance, _debtBalance);

    vm.expectRevert(bytes('AccountingEngine/not-enough-debt-being-auctioned'));
    accountingEngine.cancelAuctionedDebtWithSurplus(_rad);
  }

  function test_Revert_CoinBalanceLtRad(uint256 _rad, uint256 _totalBalance, uint256 _coinBalance) public {
    vm.assume(_rad > 0 && _rad <= _totalBalance && _rad > _coinBalance);
    _mockTotalOnAuctionDebt(_totalBalance);
    _mockCoinBalance(_coinBalance);

    vm.expectRevert(bytes('AccountingEngine/insufficient-surplus'));

    accountingEngine.cancelAuctionedDebtWithSurplus(_rad);
  }
}

contract Unit_AccountingEngine_AuctionDebt is Base {
  event AuctionDebt(uint256 indexed _id, uint256 _totalOnAuctionDebt, uint256 _debtBalance);

  function setUp() public virtual override {
    super.setUp();

    _mockCoinAndDebtBalance(0, 0);
    _mockDebtAuctionBidSize(0);
    _mockTotalQueuedDebt(0);
    _mockTotalOnAuctionDebt(0);
    _mockProtocolTokenDebtAuctionHouse(newAddress());
    _mockProtocolTokenAuthorityAuthorizationDebtAuctionHouse(1);
    _mockDebtStartAuction(1, 0, 0);

    vm.prank(deployer);
    _mockProtocolTokenAuthority(address(mockProtocolTokenAuthority));
  }

  function _assumeHappyPath(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) internal {
    vm.assume(notOverflow(_totalQueuedDebt, _totalOnAuctionDebt));
    vm.assume(
      _debtBalance >= _totalOnAuctionDebt + _totalQueuedDebt
        && _debtAuctionBidSize <= _debtBalance - _totalQueuedDebt - _totalOnAuctionDebt
    );
  }

  function _mockValues(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt,
    uint256 _debtStartAuctionId
  ) internal {
    _mockDebtAuctionBidSize(_debtAuctionBidSize);
    _mockDebtBalance(_debtBalance);
    _mockTotalQueuedDebt(_totalQueuedDebt);
    _mockTotalOnAuctionDebt(_totalOnAuctionDebt);
    _mockDebtStartAuction(_debtStartAuctionId);
  }

  function test_Call_SAFEEngine_CoinBalance(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine))
    );

    accountingEngine.auctionDebt();
  }

  function test_Call_SAFEEngine_SettleDebt(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, mockSafeEngine.coinBalance(address(accountingEngine)))
    );

    accountingEngine.auctionDebt();
  }

  function test_Call_DebtAuctionHouse_ProtocolToken(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    vm.expectCall(address(mockDebtAuctionHouse), abi.encodeWithSelector(IDebtAuctionHouse.protocolToken.selector));

    accountingEngine.auctionDebt();
  }

  function test_Call_DebtAuctionHouse_StartAuction(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    vm.expectCall(
      address(mockDebtAuctionHouse),
      abi.encodeWithSelector(
        IDebtAuctionHouse.startAuction.selector,
        address(accountingEngine),
        accountingEngine.initialDebtAuctionMintedTokens(),
        _debtAuctionBidSize
      )
    );

    accountingEngine.auctionDebt();
  }

  function test_Call_ProtocolTokenAuthority_AuthorizedAccounts(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    vm.expectCall(
      address(mockProtocolTokenAuthority),
      abi.encodeWithSelector(IProtocolTokenAuthority.authorizedAccounts.selector, address(mockDebtAuctionHouse))
    );

    accountingEngine.auctionDebt();
  }

  function test_Set_TotalAuctionOnDebt(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    accountingEngine.auctionDebt();

    assertEq(accountingEngine.totalOnAuctionDebt(), _totalOnAuctionDebt + _debtAuctionBidSize);
  }

  function test_Set_TotalAuctionOnDebt_SystemStakingPool(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);
    _mockDebtStartAuction(1);
    _mockSystemStakingPool(true);

    accountingEngine.auctionDebt();

    assertEq(accountingEngine.totalOnAuctionDebt(), _totalOnAuctionDebt + _debtAuctionBidSize);
  }

  function test_Emit_AuctionDebt(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    _assumeHappyPath(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    vm.expectEmit(true, false, false, true);
    emit AuctionDebt(1, _totalOnAuctionDebt + _debtAuctionBidSize, _debtBalance);

    accountingEngine.auctionDebt();
  }

  function test_Revert_DebtAuctionBidSizeGtUnqueuedUnauctionedDebt(
    uint256 _debtAuctionBidSize,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    vm.assume(notOverflow(_totalQueuedDebt, _totalOnAuctionDebt));
    vm.assume(
      _debtBalance > _totalQueuedDebt + _totalOnAuctionDebt
        && _debtAuctionBidSize > _debtBalance - _totalQueuedDebt - _totalOnAuctionDebt
    );
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);

    vm.expectRevert(bytes('AccountingEngine/insufficient-debt'));

    accountingEngine.auctionDebt();
  }

  function test_Revert_DebtIsNotSettled(
    uint256 _debtAuctionBidSize,
    uint256 _coinBalance,
    uint256 _debtBalance,
    uint256 _totalQueuedDebt,
    uint256 _totalOnAuctionDebt
  ) public {
    vm.assume(notOverflow(_totalQueuedDebt, _totalOnAuctionDebt));
    vm.assume(_coinBalance > 0 && _debtBalance >= _totalOnAuctionDebt + _totalQueuedDebt);
    uint256 _unqueuedUnauctionedDebt = _debtBalance - _totalQueuedDebt - _totalOnAuctionDebt;
    vm.assume(_debtAuctionBidSize <= _unqueuedUnauctionedDebt && _coinBalance <= _unqueuedUnauctionedDebt);
    _mockValues(_debtAuctionBidSize, _debtBalance, _totalQueuedDebt, _totalOnAuctionDebt, 1);
    _mockCoinBalance(_coinBalance);

    vm.expectRevert(bytes('AccountingEngine/surplus-not-zero'));

    accountingEngine.auctionDebt();
  }

  function test_Revert_ProtocolTokenIsZeroAddress() public {
    _mockProtocolTokenDebtAuctionHouse(address(0));

    vm.expectRevert(bytes('AccountingEngine/debt-auction-house-null-prot'));

    accountingEngine.auctionDebt();
  }

  function test_Revert_AccountIsNotAuthorizedByProtocolAuthority() public {
    _mockProtocolTokenAuthorityAuthorizationDebtAuctionHouse(0);

    vm.expectRevert(bytes('AccountingEngine/debt-auction-house-cannot-print-prot'));

    accountingEngine.auctionDebt();
  }

  function test_Revert_CannotPrintProtocolTokens() public {
    _mockSystemStakingPool(false);
    _mockSystemStakingPoolAddress();

    vm.expectRevert(bytes('AccountingEngine/staking-pool-denies-printing'));

    accountingEngine.auctionDebt();
  }
}

contract Unit_AccountingEngine_AuctionSurplus is Base {
  event AuctionSurplus(uint256 indexed _id, uint256 _lastSurplusAuctionTime, uint256 _coinBalance);

  function setUp() public virtual override {
    super.setUp();

    _mockCoinAndDebtBalance(5, 0);
    uint256 _amountToSell = 1;
    _mockExtraSurplusIsTransferred(0);
    _mockSurplusAuctionAmountToSell(_amountToSell);
    _mockSurplusBuffer(0);
    _mockTotalQueuedDebt(0);
    _mockProtocolTokenSurplusAuctionHouse(newAddress());
    _mockSurplusAuctionHouse(address(mockSurplusAuctionHouse));
    _mockSurplusStartAuction(1);
    _mockSurplusStartAuction(1, _amountToSell);
  }

  function _assumeHappyPath(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) internal {
    vm.assume(notOverflow(_surplusAuctionAmountToSell, _surplusBuffer));
    vm.assume(_coinBalance >= _surplusAuctionAmountToSell + _surplusBuffer);
    vm.assume(_extraSurplusIsTransferred != 1);
    vm.assume(_surplusAuctionAmountToSell > 0);
  }

  function _mockValues(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance,
    uint256 _debtBalance
  ) internal {
    _mockExtraSurplusIsTransferred(_extraSurplusIsTransferred);
    _mockSurplusAuctionAmountToSell(_surplusAuctionAmountToSell);
    _mockSurplusBuffer(_surplusBuffer);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);
    _mockSurplusStartAuction(1);
  }

  function test_Call_SAFEEngine_SettleDebt(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeHappyPath(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance);
    _mockValues(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, 0));

    accountingEngine.auctionSurplus();
  }

  function test_Call_SAFEEngine_DebtBalance(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeHappyPath(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance);
    _mockValues(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.debtBalance.selector, address(accountingEngine))
    );

    accountingEngine.auctionSurplus();
  }

  function test_Call_SurplusAuctionHouse_ProtocolToken(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeHappyPath(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance);
    _mockValues(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(address(mockSurplusAuctionHouse), abi.encodeWithSelector(ISurplusAuctionHouse.protocolToken.selector));

    accountingEngine.auctionSurplus();
  }

  function test_Call_SurplusAuctionHouse_StartAuction(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeHappyPath(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance);
    _mockValues(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(
      address(mockSurplusAuctionHouse),
      abi.encodeWithSelector(ISurplusAuctionHouse.startAuction.selector, _surplusAuctionAmountToSell, 0)
    );

    vm.warp(block.timestamp + 1);

    accountingEngine.auctionSurplus();

    assertEq(accountingEngine.lastSurplusAuctionTime(), block.timestamp);
  }

  function test_Set_LastSurplusAuctionTime(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeHappyPath(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance);
    _mockValues(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, 0);

    vm.warp(block.timestamp + 1);
    accountingEngine.auctionSurplus();

    assertEq(accountingEngine.lastSurplusAuctionTime(), block.timestamp);
  }

  function test_Set_LastSurplusTransferTime(
    uint256 _extraSurplusIsTransferred,
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeHappyPath(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance);
    _mockValues(_extraSurplusIsTransferred, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, 0);
    vm.warp(block.timestamp + 1);

    accountingEngine.auctionSurplus();

    assertEq(accountingEngine.lastSurplusTransferTime(), block.timestamp);
  }

  function test_Emit_AuctionSurplus(uint256 _coinBalance, uint256 _auctionId) public {
    vm.assume(_coinBalance > 0);
    _mockCoinBalance(_coinBalance);
    _mockSurplusStartAuction(_auctionId);

    vm.expectEmit(true, false, false, true);
    emit AuctionSurplus(_auctionId, block.timestamp, _coinBalance);

    accountingEngine.auctionSurplus();
  }

  function test_Revert_ExtraSurplusIsTransferredIs1() public {
    _mockExtraSurplusIsTransferred(1);

    vm.expectRevert(bytes('AccountingEngine/surplus-transfer-no-auction'));
    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusAuctionAmountToSellIsZero() public {
    _mockSurplusAuctionAmountToSell(0);

    vm.expectRevert(bytes('AccountingEngine/null-amount-to-auction'));

    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusAuctionDelayNotPassed(uint128 _surplusAuctionDelay, uint256 _timeElapsed) public {
    vm.assume(_timeElapsed < _surplusAuctionDelay);
    _mockSurplusAuctionDelay(_surplusAuctionDelay);
    _mockLastSurplusAuctionTime(block.timestamp);
    vm.warp(block.timestamp + _timeElapsed);

    vm.expectRevert(bytes('AccountingEngine/surplus-auction-delay-not-passed'));

    accountingEngine.auctionSurplus();
  }

  function test_Revert_InsufficientSurplus(
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    vm.assume(notOverflow(_surplusAuctionAmountToSell, _surplusBuffer));
    vm.assume(_coinBalance < _surplusAuctionAmountToSell + _surplusBuffer);
    vm.assume(_surplusAuctionAmountToSell > 0);
    _mockValues(0, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, 0);

    vm.expectRevert(bytes('AccountingEngine/insufficient-surplus'));

    accountingEngine.auctionSurplus();
  }

  //  TODO: fix over/under flow
  function test_Revert_DebtIsNotZero1(
    uint256 _surplusAuctionAmountToSell,
    uint256 _surplusBuffer,
    uint256 _debtBalance,
    uint256 _coinBalance
  ) public {
    vm.assume(_debtBalance > 0);
    vm.assume(_surplusAuctionAmountToSell > 0);
    vm.assume(notOverflow(_surplusAuctionAmountToSell, _surplusBuffer, _debtBalance));
    vm.assume(_coinBalance >= _surplusAuctionAmountToSell + _surplusBuffer + _debtBalance);

    _mockValues(0, _surplusAuctionAmountToSell, _surplusBuffer, _coinBalance, _debtBalance);

    vm.expectRevert(bytes('AccountingEngine/debt-not-zero'));

    accountingEngine.auctionSurplus();
  }
}

contract Unit_AccountingEngine_TransferExtraSurplus is Base {
  address extraSurplusReceiver = newAddress();

  event TransferExtraSurplus(
    address indexed _extraSurplusReceiver, uint256 _lastSurplusAuctionTime, uint256 _coinBalance
  );

  function setUp() public virtual override {
    super.setUp();

    _mockExtraSurplusIsTransferred(1);
    _mockTotalQueuedDebt(0);
    _mockCoinAndDebtBalance(0, 0);
    _mockCoinAndDebtBalance(5, 0);
    _mockExtraSurplusReceiver(extraSurplusReceiver);
    _mockSurplusTransferAmount(1);
    _mockSurplusBuffer(0);
  }

  function _mockValues(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance,
    uint256 _debtBalance
  ) internal {
    _mockExtraSurplusReceiver(extraSurplusReceiver);
    _mockSurplusTransferAmount(_surplusTransferAmount);
    _mockSurplusBuffer(_surplusBuffer);
    _mockCoinAndDebtBalance(_coinBalance, _debtBalance);
  }

  function _assumeAndMockHappyPath(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance,
    uint256 _debtBalance
  ) internal {
    vm.assume(notOverflow(_surplusTransferAmount, _surplusBuffer, _debtBalance));
    vm.assume(_coinBalance >= _surplusTransferAmount + _surplusBuffer);
    vm.assume(_surplusTransferAmount > 0);
    _mockValues(_surplusTransferAmount, _surplusBuffer, _coinBalance, _debtBalance);
  }

  function test_Call_SAFEEngine_SettleDebt(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeAndMockHappyPath(_surplusTransferAmount, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, 0));

    accountingEngine.transferExtraSurplus();
  }

  function test_Call_SAFEEngine_TransferInternalCoins(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeAndMockHappyPath(_surplusTransferAmount, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(
        ISAFEEngine.transferInternalCoins.selector, address(accountingEngine), extraSurplusReceiver
      )
    );

    accountingEngine.transferExtraSurplus();
  }

  function test_Call_SAFEEngine_CoinBalance(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeAndMockHappyPath(_surplusTransferAmount, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine))
    );

    accountingEngine.transferExtraSurplus();
  }

  function test_Set_LastSurplusAuctionTime(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeAndMockHappyPath(_surplusTransferAmount, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine))
    );

    vm.warp(block.timestamp + 1);

    accountingEngine.transferExtraSurplus();

    assertEq(accountingEngine.lastSurplusAuctionTime(), block.timestamp);
  }

  function test_Set_LastSurplusTransferTime(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeAndMockHappyPath(_surplusTransferAmount, _surplusBuffer, _coinBalance, 0);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine))
    );

    vm.warp(block.timestamp + 1);
    accountingEngine.transferExtraSurplus();

    assertEq(accountingEngine.lastSurplusTransferTime(), block.timestamp);
  }

  function test_Emit_TransferExtraSurplus(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    _assumeAndMockHappyPath(_surplusTransferAmount, _surplusBuffer, _coinBalance, 0);

    vm.expectEmit(true, false, false, true);
    emit TransferExtraSurplus(extraSurplusReceiver, block.timestamp, _coinBalance);

    accountingEngine.transferExtraSurplus();
  }

  function test_RevertIfExtraSurplusIsNot1(uint256 _extraSurplusIsTransferred) public {
    vm.assume(_extraSurplusIsTransferred != 1);

    _mockExtraSurplusIsTransferred(_extraSurplusIsTransferred);

    vm.expectRevert(bytes('AccountingEngine/surplus-auction-not-transfer'));

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_ExtraSurplusReceiverIsZero() public {
    extraSurplusReceiver = address(0);
    _mockExtraSurplusReceiver(extraSurplusReceiver);

    vm.expectRevert(bytes('AccountingEngine/null-surplus-receiver'));

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_SurplusTransferAmountIsZero() public {
    _mockSurplusTransferAmount(0);

    vm.expectRevert(bytes('AccountingEngine/null-amount-to-transfer'));
    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_TransferDelayNotPassed(uint128 _surplusTransferDelay, uint128 _timeElapsed) public {
    vm.assume(_timeElapsed < _surplusTransferDelay);
    _mockSurplusTransferDelay(_surplusTransferDelay);

    _mockLastSurplusTransferTime(block.timestamp + _timeElapsed);

    vm.warp(block.timestamp + _timeElapsed);
    vm.expectRevert(bytes('AccountingEngine/surplus-transfer-delay-not-passed'));

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_SurplusIsInsufficient(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    vm.assume(_surplusTransferAmount > 0);
    vm.assume(notOverflow(_surplusTransferAmount, _surplusBuffer));
    vm.assume(_coinBalance < _surplusTransferAmount + _surplusBuffer);
    _mockValues(_surplusTransferAmount, _surplusBuffer, _coinBalance, 0);
    _mockCoinBalance(_coinBalance);

    vm.expectRevert(bytes('AccountingEngine/insufficient-surplus'));

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_DebtIsNotZero(
    uint256 _surplusTransferAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance,
    uint256 _debtBalance
  ) public {
    vm.assume(_surplusTransferAmount > 0);
    vm.assume(_debtBalance > 0);
    vm.assume(notOverflow(_surplusTransferAmount, _surplusBuffer, _debtBalance));
    vm.assume(_coinBalance >= _surplusTransferAmount + _surplusBuffer + _debtBalance);
    _mockValues(_surplusTransferAmount, _surplusBuffer, _coinBalance, _debtBalance);

    vm.expectRevert(bytes('AccountingEngine/debt-not-zero'));

    accountingEngine.transferExtraSurplus();
  }
}
