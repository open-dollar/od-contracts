// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {JobForTest, IJob} from '@test/mocks/JobForTest.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address user = label('user');

  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  JobForTest job;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.prank(deployer);
    job = new JobForTest(address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(job), 'Job');
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(job)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }
}

contract Unit_Job_Constructor is Base {
  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury) public {
    job = new JobForTest(_stabilityFeeTreasury, REWARD_AMOUNT);

    assertEq(address(job.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public {
    job = new JobForTest(address(mockStabilityFeeTreasury), _rewardAmount);

    assertEq(job.rewardAmount(), _rewardAmount);
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
