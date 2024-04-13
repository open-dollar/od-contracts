// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {RewardedActions} from '@contracts/proxies/actions/RewardedActions.sol';
import {CoinJoinMock, AccountingJobMock, LiquidationEngineMock, OracleJobMock} from '@test/mocks/ActionsMocks.sol';

// Testing the calls from ODProxy to RewardedActions
contract RewardedActionsTest is ActionBaseTest {
  RewardedActions rewardedActions = new RewardedActions();
  AccountingJobMock accountingJob = new AccountingJobMock();
  CoinJoinMock coinJoin = new CoinJoinMock();
  LiquidationEngineMock liquidationEngine = new LiquidationEngineMock();
  OracleJobMock oracleJob = new OracleJobMock();

  function setUp() public {
    proxy = new ODProxy(alice);
    accountingJob.reset();
    liquidationEngine.reset();
    oracleJob.reset();
    coinJoin.reset();
  }

  function test_startDebtAuction() public {
    vm.startPrank(alice);
    accountingJob._mock_setRewardAmount(100);
    proxy.execute(
      address(rewardedActions),
      abi.encodeWithSignature('startDebtAuction(address,address)', address(accountingJob), address(coinJoin))
    );
    assertTrue(accountingJob.wasWorkAuctionDebtCalled());
  }

  function test_startSurplusAuction() public {
    vm.startPrank(alice);
    accountingJob._mock_setRewardAmount(100);
    proxy.execute(
      address(rewardedActions),
      abi.encodeWithSignature('startSurplusAuction(address,address)', address(accountingJob), address(coinJoin))
    );
    assertTrue(accountingJob.wasWorkAuctionSurplusCalled());
  }

  function test_popDebtFromQueue() public {
    vm.startPrank(alice);
    accountingJob._mock_setRewardAmount(100);
    proxy.execute(
      address(rewardedActions),
      abi.encodeWithSignature('popDebtFromQueue(address,address,uint256)', address(accountingJob), address(coinJoin), 0)
    );
    assertTrue(accountingJob.wasWorkPopDebtFromQueueCalled());
  }

  function test_auctionSurplus() public {
    vm.startPrank(alice);
    accountingJob._mock_setRewardAmount(100);
    proxy.execute(
      address(rewardedActions),
      abi.encodeWithSignature('auctionSurplus(address,address)', address(accountingJob), address(coinJoin))
    );
    assertTrue(accountingJob.wasWorkAuctionSurplusCalled());
  }

  function test_liquidateSAFE() public {
    vm.startPrank(alice);
    proxy.execute(
      address(rewardedActions),
      abi.encodeWithSignature(
        'liquidateSAFE(address,address,bytes32,address)',
        address(liquidationEngine),
        address(coinJoin),
        bytes32(0),
        address(0)
      )
    );
    assertTrue(liquidationEngine.wasWorkLiquidationCalled());
  }

  function test_updateCollateralPrice() public {
    vm.startPrank(alice);
    oracleJob._mock_setRewardAmount(100);
    proxy.execute(
      address(rewardedActions),
      abi.encodeWithSignature(
        'updateCollateralPrice(address,address,bytes32)', address(oracleJob), address(coinJoin), bytes32(0)
      )
    );
    assertTrue(oracleJob.wasWorkUpdateCollateralPrice());
  }

  function test_updateRedemptionRate() public {
    vm.startPrank(alice);
    oracleJob._mock_setRewardAmount(100);
    proxy.execute(
      address(rewardedActions),
      abi.encodeWithSignature('updateRedemptionRate(address,address)', address(oracleJob), address(coinJoin))
    );
    assertTrue(oracleJob.wasWorkUpdateCollateralPrice());
  }
}
