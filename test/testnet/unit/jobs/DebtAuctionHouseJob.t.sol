// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  DebtAuctionHouseForTest, IDebtAuctionHouse, DebtAuctionHouse
} from '@testnet/mocks/DebtAuctionHouseForTest.sol';
import {DebtAuctionHouseJob} from '@contracts/jobs/DebtAuctionHouseJob.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {ODTest, stdStorage, StdStorage} from '@testnet/utils/ODTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is ODTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IDebtAuctionHouse debtAuctionHouse;
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));
  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IProtocolToken mockProtocolToken = IProtocolToken(mockContract('ProtocolToken'));
  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));

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


    vm.stopPrank();
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(debtAuctionJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }

  // function _mockShouldWork(bool _shouldWork) internal {
  //   // BUG: Accessing packed slots is not supported by Std Storage
  //   debtAuctionJob.setShouldWork(_shouldWork);
  // }
}

contract Unit_DebtAuctionHouseJob_Constructor is Base {
    function test_DebtAuctionHouseDeployment() public {
      assertEq(address(debtAuctionJob.debtAuctionHouse()), address(debtAuctionHouse), 'incorrect auction house address');
      assertEq(debtAuctionJob.rewardAmount(), REWARD_AMOUNT, 'incorrect reward amount');
      assertEq(address(debtAuctionJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury), 'incorrect treasury');
    }
}



contract Unit_DebtAuctionHouseJob_RestartAuction is Base {

  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  function test_RestartAuctionJob() public {
    
    vm.prank(authorizedAccount);
   uint256 auctionId = debtAuctionHouse.startAuction(user, 100 ether, 10 ether);

   IDebtAuctionHouse.Auction memory auction = debtAuctionHouse.auctions(auctionId);

   vm.warp(1 + auction.auctionDeadline);

   vm.prank(user);
   vm.expectEmit();
   emit Rewarded(user, REWARD_AMOUNT);
   debtAuctionJob.restartAuction(auctionId);
  }
  
}