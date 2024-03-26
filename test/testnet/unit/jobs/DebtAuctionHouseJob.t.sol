// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  DebtAuctionHouseForTest, IDebtAuctionHouse, DebtAuctionHouse
} from '@testnet/mocks/DebtAuctionHouseForTest.sol';
import {DebtAuctionHouseJob} from '@contracts/jobs/DebtAuctionHouseJob.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {ODTest, stdStorage, StdStorage} from '@testnet/utils/ODTest.t.sol';
import {Assertions} from '@libraries/Assertions.sol';
import 'forge-std/Vm.sol';

abstract contract Base is ODTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IDebtAuctionHouse debtAuctionHouse;
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));
  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IProtocolToken mockProtocolToken = IProtocolToken(mockContract('ProtocolToken'));

  DebtAuctionHouseJob debtAuctionJob;

  uint256 constant REWARD_AMOUNT = 1 ether;

  IDebtAuctionHouse.DebtAuctionHouseParams dahParams = IDebtAuctionHouse.DebtAuctionHouseParams({
    bidDecrease: 1.05e18,
    amountSoldIncrease: 1.5e18,
    bidDuration: 3 hours,
    totalAuctionLength: 2 days
  });

  function setUp() public virtual {
    vm.startPrank(deployer);

    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), dahParams);
    label(address(debtAuctionHouse), 'DebtAuctionHouse');

    debtAuctionHouse.addAuthorization(authorizedAccount);

    debtAuctionJob =
      new DebtAuctionHouseJob(address(debtAuctionHouse), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(debtAuctionJob), 'DebtAuctionJob');

    debtAuctionJob.addAuthorization(authorizedAccount);
    vm.stopPrank();
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(debtAuctionJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }
}

contract Unit_DebtAuctionHouseJob_Constructor is Base {
  function test_DebtAuctionHouseDeployment() public {
    assertEq(address(debtAuctionJob.debtAuctionHouse()), address(debtAuctionHouse), 'incorrect auction house address');
    assertEq(debtAuctionJob.rewardAmount(), REWARD_AMOUNT, 'incorrect reward amount');
    assertEq(address(debtAuctionJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury), 'incorrect treasury');
  }
}
import "forge-std/console2.sol";
contract Unit_DebtAuctionHouseJob_RestartAuction is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);
  event RestartAuction(uint256 _id, uint256 _blockTimestamp, uint256 _auctionDeadline); 

  function test_RestartAuctionJob() public {
    vm.prank(authorizedAccount);
    //start auction
    uint256 auctionId = debtAuctionHouse.startAuction(user, 100 ether, 10 ether);

    IDebtAuctionHouse.Auction memory auction = debtAuctionHouse.auctions(auctionId);
    //end the auction
    vm.warp(1 + auction.auctionDeadline);

    vm.prank(user);
    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);
    //restart auction.
    debtAuctionJob.restartAuction(auctionId);
  }

  function test_RestartAuction_NoReward_Job() public {
    vm.prank(authorizedAccount);
    //start auction
    uint256 auctionId = debtAuctionHouse.startAuction(user, 100 ether, 10 ether);

    IDebtAuctionHouse.Auction memory auction = debtAuctionHouse.auctions(auctionId);
    //end the auction
    vm.warp(1 + auction.auctionDeadline);

    vm.prank(user);
    vm.recordLogs();
    //restart auction.
    debtAuctionJob.restartAuctionWithoutReward(auctionId);

    Vm.Log[] memory logs = vm.getRecordedLogs();

    assertEq(logs[0].topics[0], keccak256('RestartAuction(uint256,uint256,uint256)'));
  }

  function test_RestartAuctionJob_Revert_AuctionNotEnded() public {
    vm.prank(authorizedAccount);
    //start auction
    uint256 auctionId = debtAuctionHouse.startAuction(user, 100 ether, 10 ether);

    vm.prank(user);
    vm.expectRevert();
    //restart auction.
    debtAuctionJob.restartAuction(auctionId);
  }
}

contract Unit_DebtAuctionHouseJob_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_DebtAuctionHouse(address _DebtAuctionHouse) public happyPath mockAsContract(_DebtAuctionHouse) {
    vm.assume(_DebtAuctionHouse != address(0));
    debtAuctionJob.modifyParameters('debtAuctionHouse', abi.encode(_DebtAuctionHouse));

    assertEq(address(debtAuctionJob.debtAuctionHouse()), _DebtAuctionHouse);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    debtAuctionJob.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(debtAuctionJob.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    debtAuctionJob.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(debtAuctionJob.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    debtAuctionJob.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    debtAuctionJob.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    debtAuctionJob.modifyParameters('unrecognizedParam', _data);
  }
}
