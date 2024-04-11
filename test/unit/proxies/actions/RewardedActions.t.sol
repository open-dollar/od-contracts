// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {RewardedActions} from '@contracts/proxies/actions/RewardedActions.sol';
import {CoinJoinMock} from './SurplusBidActions.t.sol';

contract AccountingJobMock {

  bool public wasWorkAuctionDebtCalled;
  bool public wasWorkAuctionSurplusCalled;
  bool public wasWorkPopDebtFromQueueCalled;
  uint256 public rewardAmount;

  function reset() external {
    wasWorkAuctionDebtCalled = false;
    wasWorkAuctionSurplusCalled = false;
  wasWorkPopDebtFromQueueCalled = false;
  }

  function _mock_setRewardAmount(uint256 _rewardAmount) external {
    rewardAmount = _rewardAmount;
  }

  function workAuctionDebt() external {
    wasWorkAuctionDebtCalled = true;
  }

  function workAuctionSurplus() external {
    wasWorkAuctionSurplusCalled = true;
  }

  function workPopDebtFromQueue(uint256 _debtBlockTimestamp) external {
     wasWorkPopDebtFromQueueCalled = true;
  }
}

contract LiquidationEngineMock {

  bool public wasWorkLiquidationCalled;
  uint256 public rewardAmount;

  function reset() external {
    wasWorkLiquidationCalled = false;
  }

  function _mock_setRewardAmount(uint256 _rewardAmount) external {
    rewardAmount = _rewardAmount;
  }

  function workLiquidation(bytes32 _cType, address _safe) external {
    wasWorkLiquidationCalled = true;
  }

}

contract OracleJobMock {

  bool public wasWorkUpdateCollateralPrice;
  bool public wasWorkUpdateRate;
  uint256 public rewardAmount;

  function _mock_setRewardAmount(uint256 _rewardAmount) external {
    rewardAmount = _rewardAmount;
  }

  function reset() external {
    wasWorkUpdateCollateralPrice = false;
    wasWorkUpdateRate = false;
  }

  function workUpdateCollateralPrice(bytes32 _cType) external {
    wasWorkUpdateCollateralPrice = true;
  }

  function workUpdateRate() external {
    wasWorkUpdateCollateralPrice = true;
  }

}


// Testing the calls from ODProxy to RewardedActions
contract RewardedActionsTest is ActionBaseTest {
  RewardedActions rewardedActions = new RewardedActions();
  AccountingJobMock accountingJob = new AccountingJobMock();
  CoinJoinMock coinJoin = new CoinJoinMock();
  LiquidationEngineMock liquidationEngine = new LiquidationEngineMock();
  OracleJobMock oracleJob = new OracleJobMock();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function test_startDebtAuction() public {
    accountingJob.reset();
    accountingJob._mock_setRewardAmount(100);
    vm.startPrank(alice);
    proxy.execute(address(rewardedActions), abi.encodeWithSignature('startDebtAuction(address,address)', address(accountingJob), address(coinJoin)));
    assertTrue(accountingJob.wasWorkAuctionDebtCalled());
  }

  function test_startSurplusAuction() public {
    accountingJob.reset();
    accountingJob._mock_setRewardAmount(100);
    vm.startPrank(alice);
    proxy.execute(address(rewardedActions), abi.encodeWithSignature('startSurplusAuction(address,address)', address(accountingJob), address(coinJoin)));
    assertTrue(accountingJob.wasWorkAuctionSurplusCalled());
  }

  function test_popDebtFromQueue() public {
    accountingJob.reset();
    accountingJob._mock_setRewardAmount(100);
    vm.startPrank(alice);
    proxy.execute(address(rewardedActions), abi.encodeWithSignature('popDebtFromQueue(address,address,uint256)', address(accountingJob), address(coinJoin), 0));
    assertTrue(accountingJob.wasWorkPopDebtFromQueueCalled());
  }

  function test_auctionSurplus() public {
    accountingJob.reset();
    accountingJob._mock_setRewardAmount(100);
    vm.startPrank(alice);
    proxy.execute(address(rewardedActions), abi.encodeWithSignature('auctionSurplus(address,address)', address(accountingJob), address(coinJoin)));
    assertTrue(accountingJob.wasWorkAuctionSurplusCalled());
  }

  function test_liquidateSAFE() public {
    liquidationEngine.reset();
    vm.startPrank(alice);
    proxy.execute(address(rewardedActions), abi.encodeWithSignature('liquidateSAFE(address,address,bytes32,address)', address(liquidationEngine), address(coinJoin), bytes32(0), address(0)));
    assertTrue(liquidationEngine.wasWorkLiquidationCalled());
  }

  function test_updateCollateralPrice() public {
    oracleJob.reset();
    oracleJob._mock_setRewardAmount(100);
    coinJoin.reset();
    vm.startPrank(alice);
    proxy.execute(address(rewardedActions), abi.encodeWithSignature('updateCollateralPrice(address,address,bytes32)', address(oracleJob), address(coinJoin), bytes32(0)));
    assertTrue(oracleJob.wasWorkUpdateCollateralPrice());
  }

  function test_updateRedemptionRate() public {
    oracleJob.reset();
    oracleJob._mock_setRewardAmount(100);
    vm.startPrank(alice);
    proxy.execute(address(rewardedActions), abi.encodeWithSignature('updateRedemptionRate(address,address)', address(oracleJob), address(coinJoin)));
    assertTrue(oracleJob.wasWorkUpdateCollateralPrice());
  }

}
