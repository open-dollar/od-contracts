// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AccountingJobForTest, IAccountingJob} from '@test/mocks/AccountingJobForTest.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  AccountingJobForTest accountingJob;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.startPrank(deployer);

    accountingJob =
      new AccountingJobForTest(address(mockAccountingEngine), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(accountingJob), 'AccountingJob');

    accountingJob.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockAuctionDebt(uint256 _id) internal {
    vm.mockCall(address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.auctionDebt, ()), abi.encode(_id));
  }

  function _mockAuctionSurplus(uint256 _id) internal {
    vm.mockCall(address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.auctionSurplus, ()), abi.encode(_id));
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(accountingJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }

  function _mockShouldWorkPopDebtFromQueue(bool _shouldWorkPopDebtFromQueue) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    accountingJob.setShouldWorkPopDebtFromQueue(_shouldWorkPopDebtFromQueue);
  }

  function _mockShouldWorkAuctionDebt(bool _shouldWorkAuctionDebt) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    accountingJob.setShouldWorkAuctionDebt(_shouldWorkAuctionDebt);
  }

  function _mockShouldWorkAuctionSurplus(bool _shouldWorkAuctionSurplus) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    accountingJob.setShouldWorkAuctionSurplus(_shouldWorkAuctionSurplus);
  }

  function _mockShouldWorkTransferExtraSurplus(bool _shouldWorkTransferExtraSurplus) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    accountingJob.setShouldWorkTransferExtraSurplus(_shouldWorkTransferExtraSurplus);
  }
}

contract Unit_AccountingJob_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new AccountingJobForTest(address(mockAccountingEngine), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Set_StabilityFeeTreasury() public happyPath {
    assertEq(address(accountingJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury));
  }

  function test_Set_RewardAmount() public happyPath {
    assertEq(accountingJob.rewardAmount(), REWARD_AMOUNT);
  }

  function test_Set_AccountingEngine(address _accountingEngine) public happyPath mockAsContract(_accountingEngine) {
    accountingJob = new AccountingJobForTest(_accountingEngine, address(mockStabilityFeeTreasury), REWARD_AMOUNT);

    assertEq(address(accountingJob.accountingEngine()), _accountingEngine);
  }

  function test_Set_ShouldWorkPopDebtFromQueue() public happyPath {
    assertEq(accountingJob.shouldWorkPopDebtFromQueue(), true);
  }

  function test_Set_ShouldWorkAuctionDebt() public happyPath {
    assertEq(accountingJob.shouldWorkAuctionDebt(), true);
  }

  function test_Set_ShouldWorkAuctionSurplus() public happyPath {
    assertEq(accountingJob.shouldWorkAuctionSurplus(), true);
  }

  function test_Set_ShouldWorkTransferExtraSurplus() public happyPath {
    assertEq(accountingJob.shouldWorkTransferExtraSurplus(), true);
  }

  function test_Revert_Null_AccountingEngine() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new AccountingJobForTest(address(0), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new AccountingJobForTest(address(mockAccountingEngine), address(0), REWARD_AMOUNT);
  }

  function test_Revert_Null_RewardAmount() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new AccountingJobForTest(address(mockAccountingEngine), address(mockStabilityFeeTreasury), 0);
  }
}

contract Unit_AccountingJob_WorkPopDebtFromQueue is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  modifier happyPath() {
    vm.startPrank(user);

    _mockValues(true);
    _;
  }

  function _mockValues(bool _shouldWorkPopDebtFromQueue) internal {
    _mockShouldWorkPopDebtFromQueue(_shouldWorkPopDebtFromQueue);
  }

  function test_Revert_NotWorkable(uint256 _debtBlockTimestamp) public {
    _mockValues(false);

    vm.expectRevert(IJob.NotWorkable.selector);

    accountingJob.workPopDebtFromQueue(_debtBlockTimestamp);
  }

  function test_Call_AccountingEngine_PopDebtFromQueue(uint256 _debtBlockTimestamp) public happyPath {
    vm.expectCall(
      address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.popDebtFromQueue, (_debtBlockTimestamp)), 1
    );

    accountingJob.workPopDebtFromQueue(_debtBlockTimestamp);
  }

  function test_Emit_Rewarded(uint256 _debtBlockTimestamp) public happyPath {
    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    accountingJob.workPopDebtFromQueue(_debtBlockTimestamp);
  }
}

contract Unit_AccountingJob_WorkAuctionDebt is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  modifier happyPath(uint256 _id) {
    vm.startPrank(user);

    _mockValues(true, _id);
    _;
  }

  function _mockValues(bool _shouldWorkAuctionDebt, uint256 _id) internal {
    _mockShouldWorkAuctionDebt(_shouldWorkAuctionDebt);
    _mockAuctionDebt(_id);
  }

  function test_Revert_NotWorkable() public {
    _mockValues(false, 0);

    vm.expectRevert(IJob.NotWorkable.selector);

    accountingJob.workAuctionDebt();
  }

  function test_Call_AccountingEngine_AuctionDebt(uint256 _id) public happyPath(_id) {
    vm.expectCall(address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.auctionDebt, ()), 1);

    accountingJob.workAuctionDebt();
  }

  function test_Emit_Rewarded(uint256 _id) public happyPath(_id) {
    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    accountingJob.workAuctionDebt();
  }
}

contract Unit_AccountingJob_WorkAuctionSurplus is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  modifier happyPath(uint256 _id) {
    vm.startPrank(user);

    _mockValues(true, _id);
    _;
  }

  function _mockValues(bool _shouldWorkAuctionSurplus, uint256 _id) internal {
    _mockShouldWorkAuctionSurplus(_shouldWorkAuctionSurplus);
    _mockAuctionSurplus(_id);
  }

  function test_Revert_NotWorkable() public {
    _mockValues(false, 0);

    vm.expectRevert(IJob.NotWorkable.selector);

    accountingJob.workAuctionSurplus();
  }

  function test_Call_AccountingEngine_AuctionSurplus(uint256 _id) public happyPath(_id) {
    vm.expectCall(address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.auctionSurplus, ()), 1);

    accountingJob.workAuctionSurplus();
  }

  function test_Emit_Rewarded(uint256 _id) public happyPath(_id) {
    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    accountingJob.workAuctionSurplus();
  }
}

contract Unit_AccountingJob_WorkTransferExtraSurplus is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  modifier happyPath() {
    vm.startPrank(user);

    _mockValues(true);
    _;
  }

  function _mockValues(bool _shouldWorkTransferExtraSurplus) internal {
    _mockShouldWorkTransferExtraSurplus(_shouldWorkTransferExtraSurplus);
  }

  function test_Revert_NotWorkable() public {
    _mockValues(false);

    vm.expectRevert(IJob.NotWorkable.selector);

    accountingJob.workTransferExtraSurplus();
  }

  function test_Call_AccountingEngine_TransferExtraSurplus() public happyPath {
    vm.expectCall(address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.transferExtraSurplus, ()), 1);

    accountingJob.workTransferExtraSurplus();
  }

  function test_Emit_Rewarded() public happyPath {
    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    accountingJob.workTransferExtraSurplus();
  }
}

contract Unit_AccountingJob_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_AccountingEngine(address _accountingEngine) public happyPath mockAsContract(_accountingEngine) {
    accountingJob.modifyParameters('accountingEngine', abi.encode(_accountingEngine));

    assertEq(address(accountingJob.accountingEngine()), _accountingEngine);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    accountingJob.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(accountingJob.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_ShouldWorkPopDebtFromQueue(bool _shouldWorkPopDebtFromQueue) public happyPath {
    accountingJob.modifyParameters('shouldWorkPopDebtFromQueue', abi.encode(_shouldWorkPopDebtFromQueue));

    assertEq(accountingJob.shouldWorkPopDebtFromQueue(), _shouldWorkPopDebtFromQueue);
  }

  function test_Set_ShouldWorkAuctionDebt(bool _shouldWorkAuctionDebt) public happyPath {
    accountingJob.modifyParameters('shouldWorkAuctionDebt', abi.encode(_shouldWorkAuctionDebt));

    assertEq(accountingJob.shouldWorkAuctionDebt(), _shouldWorkAuctionDebt);
  }

  function test_Set_ShouldWorkAuctionSurplus(bool _shouldWorkAuctionSurplus) public happyPath {
    accountingJob.modifyParameters('shouldWorkAuctionSurplus', abi.encode(_shouldWorkAuctionSurplus));

    assertEq(accountingJob.shouldWorkAuctionSurplus(), _shouldWorkAuctionSurplus);
  }

  function test_Set_ShouldWorkTransferExtraSurplus(bool _shouldWorkTransferExtraSurplus) public happyPath {
    accountingJob.modifyParameters('shouldWorkTransferExtraSurplus', abi.encode(_shouldWorkTransferExtraSurplus));

    assertEq(accountingJob.shouldWorkTransferExtraSurplus(), _shouldWorkTransferExtraSurplus);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    accountingJob.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(accountingJob.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_AccountingEngine() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    accountingJob.modifyParameters('accountingEngine', abi.encode(address(0)));
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    accountingJob.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    accountingJob.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    accountingJob.modifyParameters('unrecognizedParam', _data);
  }
}
