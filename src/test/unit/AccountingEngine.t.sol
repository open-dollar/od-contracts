// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAccountingEngine, IAuthorizable} from '@interfaces/IAccountingEngine.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {SettlementSurplusAuctioneer} from '@contracts/settlement/SettlementSurplusAuctioneer.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {IProtocolTokenAuthority} from '@interfaces/external/IProtocolTokenAuthority.sol';
import {ISystemStakingPool} from '@interfaces/external/ISystemStakingPool.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

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
    AccountingEngine.AccountingEngineParams memory _params = accountingEngine.params();
    _mockSurplusStartAuction(_id, _params.surplusAmount);
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

  function _mockSurplusAuctionHouse(address _surplusAuctionHouse) internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.surplusAuctionHouse.selector).checked_write(
      _surplusAuctionHouse
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

  function _mockSystemStakingPoolAddress() internal {
    stdstore.target(address(accountingEngine)).sig(IAccountingEngine.systemStakingPool.selector).checked_write(
      address(stakingPool)
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

  function _mockDebtStartAuction(uint256 _id) internal {
    AccountingEngine.AccountingEngineParams memory _params = accountingEngine.params();
    _mockDebtStartAuction(_id, _params.debtAuctionMintedTokens, _params.debtAuctionBidSize);
  }
}

contract Unit_AccountingEngine_Constructor is Base {
  function test_Set_Parameters() public {
    assertEq(address(accountingEngine.safeEngine()), address(mockSafeEngine));
    assertEq(address(accountingEngine.surplusAuctionHouse()), address(mockSurplusAuctionHouse));
    assertEq(address(accountingEngine.debtAuctionHouse()), address(mockDebtAuctionHouse));
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

    (bool _success, bytes memory _data) = address(accountingEngine).staticcall(abi.encodeWithSignature('params()'));

    assert(_success);
    assertEq(keccak256(abi.encode(_fuzz)), keccak256(_data));
  }

  function test_ModifyParameters_SurplusAuctionHouse(address _surplusAuctionHouse) public authorized {
    address _previousSurplusAuctionHouse = address(accountingEngine.surplusAuctionHouse());
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.denySAFEModification.selector, _previousSurplusAuctionHouse),
      1
    );
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeWithSelector(ISAFEEngine.approveSAFEModification.selector, _surplusAuctionHouse),
      1
    );

    accountingEngine.modifyParameters('surplusAuctionHouse', abi.encode(_surplusAuctionHouse));

    assertEq(_surplusAuctionHouse, address(accountingEngine.surplusAuctionHouse()));
  }

  function test_ModifyParameters_SystemStakingPool(address _systemStakingPool) public authorized {
    vm.mockCall(_systemStakingPool, abi.encodeWithSignature('canPrintProtocolTokens()'), abi.encode(0));
    vm.expectCall(_systemStakingPool, abi.encodeWithSignature('canPrintProtocolTokens()'), 1);

    accountingEngine.modifyParameters('systemStakingPool', abi.encode(_systemStakingPool));

    assertEq(_systemStakingPool, address(accountingEngine.systemStakingPool()));
  }

  function test_ModifyParameters_DebtAuctionHouse(address _debtAuctionHouse) public authorized {
    accountingEngine.modifyParameters('debtAuctionHouse', abi.encode(_debtAuctionHouse));

    assertEq(_debtAuctionHouse, address(accountingEngine.debtAuctionHouse()));
  }

  function test_ModifyParameters_ProtocolTokenAuthority(address _protocolTokenAuthority) public authorized {
    accountingEngine.modifyParameters('protocolTokenAuthority', abi.encode(_protocolTokenAuthority));

    assertEq(_protocolTokenAuthority, address(accountingEngine.protocolTokenAuthority()));
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
    vm.assume(notOverflow(_debtBalance, _totalQueuedDebt, _totalOnAuctionDebt));
    vm.assume(_debtBalance >= _totalQueuedDebt + _totalOnAuctionDebt);
    uint256 _unqueuedUnauctionedDebt = _debtBalance - _totalQueuedDebt - _totalOnAuctionDebt;
    _mockValues(_debtBalance, _totalQueuedDebt, _totalOnAuctionDebt);

    assertEq(accountingEngine.unqueuedUnauctionedDebt(), _unqueuedUnauctionedDebt);
  }
}

contract Unit_AccountingEngine_PushDebtToQueue is Base {
  event PushDebtToQueue(uint256 indexed _timestamp, uint256 _debtQueueBlock, uint256 _totalQueuedDebt);

  function _assumeHappyPath(uint256 _a, uint256 _b) internal pure {
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
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    accountingEngine.pushDebtToQueue(_debtBlock);
  }
}

contract Unit_AccountingEngine_PopDebtFromQueue is Base {
  event PopDebtFromQueue(uint256 indexed _timestamp, uint256 _debtQueueBlock, uint256 _totalQueuedDebt);

  function _assumeHappyPath(uint256 _a, uint256 _b) internal pure {
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
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 2
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

    vm.expectEmit(true, false, false, true);
    emit SettleDebt(_scenario.rad, _scenario.coinBalance, _scenario.debtBalance);

    accountingEngine.settleDebt(_scenario.rad);
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

  function _assumeHappyPath(uint256 _rad, uint256 _totalBalance, uint256 _debtBalance) internal pure {
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
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 2
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

  struct AuctionDebtScenario {
    uint256 debtAuctionBidSize;
    uint256 debtBalance;
    uint256 totalQueuedDebt;
    uint256 totalOnAuctionDebt;
  }

  function _assumeHappyPath(AuctionDebtScenario memory _scenario) internal pure {
    vm.assume(notOverflow(_scenario.totalQueuedDebt, _scenario.totalOnAuctionDebt));
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
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 4
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

  function test_Call_DebtAuctionHouse_ProtocolToken(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    vm.expectCall(address(mockDebtAuctionHouse), abi.encodeWithSelector(IDebtAuctionHouse.protocolToken.selector));

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

  function test_Call_ProtocolTokenAuthority_AuthorizedAccounts(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    vm.expectCall(
      address(mockProtocolTokenAuthority),
      abi.encodeWithSelector(IProtocolTokenAuthority.authorizedAccounts.selector, address(mockDebtAuctionHouse))
    );

    accountingEngine.auctionDebt();
  }

  function test_Set_TotalAuctionOnDebt(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    accountingEngine.auctionDebt();

    assertEq(accountingEngine.totalOnAuctionDebt(), _scenario.totalOnAuctionDebt + _scenario.debtAuctionBidSize);
  }

  function test_Set_TotalAuctionOnDebt_SystemStakingPool(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);
    _mockDebtStartAuction(1);
    _mockSystemStakingPool(true);

    accountingEngine.auctionDebt();

    assertEq(accountingEngine.totalOnAuctionDebt(), _scenario.totalOnAuctionDebt + _scenario.debtAuctionBidSize);
  }

  function test_Emit_AuctionDebt(AuctionDebtScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario, 1);

    vm.expectEmit(true, false, false, true);
    emit AuctionDebt(1, _scenario.totalOnAuctionDebt + _scenario.debtAuctionBidSize, _scenario.debtBalance);

    accountingEngine.auctionDebt();
  }

  function test_Revert_DebtAuctionBidSizeGtUnqueuedUnauctionedDebt(AuctionDebtScenario memory _scenario) public {
    vm.assume(notOverflow(_scenario.totalQueuedDebt, _scenario.totalOnAuctionDebt));
    vm.assume(
      _scenario.debtBalance > _scenario.totalQueuedDebt + _scenario.totalOnAuctionDebt
        && _scenario.debtAuctionBidSize > _scenario.debtBalance - _scenario.totalQueuedDebt - _scenario.totalOnAuctionDebt
    );
    _mockValues(_scenario, 1);

    vm.expectRevert(bytes('AccountingEngine/insufficient-debt'));

    accountingEngine.auctionDebt();
  }

  function test_Revert_DebtIsNotSettled(AuctionDebtScenario memory _scenario, uint256 _coinBalance) public {
    vm.assume(notOverflow(_scenario.totalQueuedDebt, _scenario.totalOnAuctionDebt));
    vm.assume(_coinBalance > 0 && _scenario.debtBalance >= _scenario.totalOnAuctionDebt + _scenario.totalQueuedDebt);
    uint256 _unqueuedUnauctionedDebt = _scenario.debtBalance - _scenario.totalQueuedDebt - _scenario.totalOnAuctionDebt;
    vm.assume(_scenario.debtAuctionBidSize <= _unqueuedUnauctionedDebt && _coinBalance <= _unqueuedUnauctionedDebt);
    _mockValues(_scenario, 1);
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
  event AuctionSurplus(uint256 indexed _id, uint256 _lastSurplusTime, uint256 _coinBalance);

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
    _mockProtocolTokenSurplusAuctionHouse(newAddress());
    _mockSurplusAuctionHouse(address(mockSurplusAuctionHouse));
    _mockSurplusStartAuction(1);
    _mockSurplusStartAuction(1, _amountToSell);
  }

  function _assumeHappyPath(AuctionSurplusScenario memory _scenario) internal pure {
    vm.assume(notOverflow(_scenario.surplusAmount, _scenario.surplusBuffer));
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
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.debtBalance.selector, address(accountingEngine)), 5
    );

    accountingEngine.auctionSurplus();
  }

  function test_Call_SurplusAuctionHouse_ProtocolToken(AuctionSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(0, 0, _scenario);

    vm.expectCall(address(mockSurplusAuctionHouse), abi.encodeWithSelector(ISurplusAuctionHouse.protocolToken.selector));

    accountingEngine.auctionSurplus();
  }

  function test_Call_SurplusAuctionHouse_StartAuction(AuctionSurplusScenario memory _scenario) public {
    _assumeHappyPath(_scenario);
    _mockValues(0, 0, _scenario);

    vm.expectCall(
      address(mockSurplusAuctionHouse),
      abi.encodeWithSelector(ISurplusAuctionHouse.startAuction.selector, _scenario.surplusAmount, 0)
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

  function test_Emit_AuctionSurplus(uint256 _coinBalance, uint256 _auctionId) public {
    vm.assume(_coinBalance > 0);
    _mockCoinBalance(_coinBalance);
    _mockSurplusStartAuction(_auctionId);

    vm.expectEmit(true, false, false, true);
    emit AuctionSurplus(_auctionId, block.timestamp, _coinBalance);

    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusIsTransferredIs1() public {
    _mockSurplusIsTransferred(1);

    vm.expectRevert(bytes('AccountingEngine/surplus-transfer-no-auction'));
    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusAuctionAmountToSellIsZero() public {
    _mockSurplusAmount(0);

    vm.expectRevert(bytes('AccountingEngine/null-amount-to-auction'));

    accountingEngine.auctionSurplus();
  }

  function test_Revert_SurplusAuctionDelayNotPassed(uint128 _surplusDelay, uint256 _timeElapsed) public {
    vm.assume(_timeElapsed < _surplusDelay);
    _mockSurplusDelay(_surplusDelay);
    _mockLastSurplusTime(block.timestamp);
    vm.warp(block.timestamp + _timeElapsed);

    vm.expectRevert(bytes('AccountingEngine/surplus-auction-delay-not-passed'));

    accountingEngine.auctionSurplus();
  }

  function test_Revert_InsufficientSurplus(AuctionSurplusScenario memory _scenario) public {
    vm.assume(notOverflow(_scenario.surplusAmount, _scenario.surplusBuffer));
    vm.assume(_scenario.coinBalance < _scenario.surplusAmount + _scenario.surplusBuffer);
    vm.assume(_scenario.surplusAmount > 0);
    _mockValues(0, 0, _scenario);

    vm.expectRevert(bytes('AccountingEngine/insufficient-surplus'));

    accountingEngine.auctionSurplus();
  }

  function test_Revert_DebtIsNotZero(AuctionSurplusScenario memory _scenario, uint256 _debtBalance) public {
    vm.assume(_debtBalance > 0);
    vm.assume(_scenario.surplusAmount > 0);
    vm.assume(notOverflow(_scenario.surplusAmount, _scenario.surplusBuffer, _debtBalance));
    vm.assume(_scenario.coinBalance >= _scenario.surplusAmount + _scenario.surplusBuffer + _debtBalance);

    _mockValues(0, _debtBalance, _scenario);

    vm.expectRevert(bytes('AccountingEngine/debt-not-zero'));

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
  }

  event TransferExtraSurplus(address indexed _extraSurplusReceiver, uint256 _lastSurplusTime, uint256 _coinBalance);

  function setUp() public virtual override {
    super.setUp();

    _mockSurplusIsTransferred(1);
    _mockTotalQueuedDebt(0);
    _mockCoinAndDebtBalance(0, 0);
    _mockCoinAndDebtBalance(5, 0);
    _mockExtraSurplusReceiver(extraSurplusReceiver);
    _mockSurplusAmount(1);
    _mockSurplusBuffer(0);
  }

  function _mockValues(TransferSurplusScenario memory _scenario) internal {
    _mockExtraSurplusReceiver(extraSurplusReceiver);
    _mockSurplusAmount(_scenario.surplusAmount);
    _mockSurplusBuffer(_scenario.surplusBuffer);
    _mockCoinAndDebtBalance(_scenario.coinBalance, _scenario.debtBalance);
  }

  function _assumeHappyPath(TransferSurplusScenario memory _scenario) internal {
    vm.assume(notOverflow(_scenario.surplusAmount, _scenario.surplusBuffer, _scenario.debtBalance));
    vm.assume(_scenario.coinBalance >= _scenario.surplusAmount + _scenario.surplusBuffer);
    vm.assume(_scenario.surplusAmount > 0);
    _mockValues(_scenario);
  }

  function test_Call_SAFEEngine_SettleDebt(TransferSurplusScenario memory _scenario) public {
    _scenario.debtBalance = 0;
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.settleDebt.selector, 0));

    accountingEngine.transferExtraSurplus();
  }

  function test_Call_SAFEEngine_TransferInternalCoins(TransferSurplusScenario memory _scenario) public {
    _scenario.debtBalance = 0;
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
    _scenario.debtBalance = 0;
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 4
    );

    accountingEngine.transferExtraSurplus();
  }

  function test_Set_LastSurplusTime(TransferSurplusScenario memory _scenario) public {
    _scenario.debtBalance = 0;
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectCall(
      address(mockSafeEngine), abi.encodeWithSelector(ISAFEEngine.coinBalance.selector, address(accountingEngine)), 4
    );

    vm.warp(block.timestamp + 1);

    accountingEngine.transferExtraSurplus();

    assertEq(accountingEngine.lastSurplusTime(), block.timestamp);
  }

  function test_Emit_TransferExtraSurplus(TransferSurplusScenario memory _scenario) public {
    _scenario.debtBalance = 0;
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);

    vm.expectEmit(true, false, false, true);
    emit TransferExtraSurplus(extraSurplusReceiver, block.timestamp, _scenario.coinBalance);

    accountingEngine.transferExtraSurplus();
  }

  function test_RevertIfExtraSurplusIsNot1(uint256 _surplusIsTransferred) public {
    vm.assume(_surplusIsTransferred != 1);

    _mockSurplusIsTransferred(_surplusIsTransferred);

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
    _mockSurplusAmount(0);

    vm.expectRevert(bytes('AccountingEngine/null-amount-to-transfer'));
    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_TransferDelayNotPassed(uint128 _surplusDelay, uint128 _timeElapsed) public {
    vm.assume(_timeElapsed < _surplusDelay);
    _mockSurplusDelay(_surplusDelay);
    _mockLastSurplusTime(block.timestamp + _timeElapsed);

    vm.warp(block.timestamp + _timeElapsed);
    vm.expectRevert(bytes('AccountingEngine/surplus-transfer-delay-not-passed'));

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_SurplusIsInsufficient(
    uint256 _surplusAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance
  ) public {
    vm.assume(_surplusAmount > 0);
    vm.assume(notOverflow(_surplusAmount, _surplusBuffer));
    vm.assume(_coinBalance < _surplusAmount + _surplusBuffer);

    _mockValues(TransferSurplusScenario(_surplusAmount, _surplusBuffer, _coinBalance, 0));
    _mockCoinBalance(_coinBalance);

    vm.expectRevert(bytes('AccountingEngine/insufficient-surplus'));

    accountingEngine.transferExtraSurplus();
  }

  function test_Revert_DebtIsNotZero(
    uint256 _surplusAmount,
    uint256 _surplusBuffer,
    uint256 _coinBalance,
    uint256 _debtBalance
  ) public {
    vm.assume(_surplusAmount > 0);
    vm.assume(_debtBalance > 0);
    vm.assume(notOverflow(_surplusAmount, _surplusBuffer, _debtBalance));
    vm.assume(_coinBalance >= _surplusAmount + _surplusBuffer + _debtBalance);
    _mockValues(TransferSurplusScenario(_surplusAmount, _surplusBuffer, _coinBalance, _debtBalance));

    vm.expectRevert(bytes('AccountingEngine/debt-not-zero'));

    accountingEngine.transferExtraSurplus();
  }
}
