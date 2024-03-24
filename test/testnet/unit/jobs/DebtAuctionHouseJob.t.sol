// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  DebtAuctionHouseForTest, IDebtAuctionHouse, DebtAuctionHouse
} from '@testnet/mocks/DebtAuctionHouseForTest.sol';
import {DebtAuctionHouseJob} from '@contracts/jobs/DebtAuctionHouseJob.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
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

  IDebtAuctionHouse mockDebtAuctionHouse = IDebtAuctionHouse(mockContract('DebtAuctionHouse'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  DebtAuctionHouseJob debtAuctionJob;

  uint256 constant REWARD_AMOUNT = 1 ether;

  function setUp() public virtual {
    vm.startPrank(deployer);

    debtAuctionJob =
      new DebtAuctionHouseJob(address(mockDebtAuctionHouse), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(debtAuctionJob), 'DebtAuctionJob');

    debtAuctionJob.addAuthorization(authorizedAccount);

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

contract Unit_DebtAUctionHouseJob_Constructor is Base {
    function test_DebtAuctionHouse()public{
      assertEq(debtAuctionJob.debtAuctionHouse(), address(mockDebtAuctionHouse), 'incorrect auction house address');
    }
}