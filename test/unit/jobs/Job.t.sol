// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JobForTest, IJob} from '@test/mocks/JobForTest.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  JobForTest job;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.startPrank(deployer);

    job = new JobForTest(address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(job), 'Job');

    job.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(job)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }
}

contract Unit_Job_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new JobForTest(address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Set_StabilityFeeTreasury() public happyPath {
    assertEq(address(job.stabilityFeeTreasury()), address(mockStabilityFeeTreasury));
  }

  function test_Set_RewardAmount() public happyPath {
    assertEq(job.rewardAmount(), REWARD_AMOUNT);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new JobForTest(address(0), REWARD_AMOUNT);
  }

  function test_Revert_Null_RewardAmount() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new JobForTest(address(mockStabilityFeeTreasury), 0);
  }
}

contract Unit_Job_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    job.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(job.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    job.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(job.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    job.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    job.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    job.modifyParameters('unrecognizedParam', _data);
  }
}

contract Unit_Job_Reward is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  modifier happyPath(uint256 _rewardAmount) {
    vm.startPrank(user);

    _mockValues(_rewardAmount);
    _;
  }

  function _mockValues(uint256 _rewardAmount) internal {
    _mockRewardAmount(_rewardAmount);
  }

  function test_Call_StabilityFeeTreasury_PullFunds(uint256 _rewardAmount) public happyPath(_rewardAmount) {
    vm.expectCall(
      address(mockStabilityFeeTreasury), abi.encodeCall(mockStabilityFeeTreasury.pullFunds, (user, _rewardAmount)), 1
    );

    job.rewardModifier();
  }

  function test_Emit_Rewarded(uint256 _rewardAmount) public happyPath(_rewardAmount) {
    vm.expectEmit();
    emit Rewarded(user, _rewardAmount);

    job.rewardModifier();
  }
}
