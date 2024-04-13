// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {SurplusBidActions} from '@contracts/proxies/actions/SurplusBidActions.sol';

import {CoinJoinMock, SafeEngineMock, SurplusActionsHouseMock} from '@test/mocks/ActionsMocks.sol';

contract SurplusBidActionTest is ActionBaseTest {
  SurplusBidActions surplusBidActions = new SurplusBidActions();
  SurplusActionsHouseMock surplusActionsHouseMock = new SurplusActionsHouseMock();
  CoinJoinMock coinJoin = new CoinJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
    surplusActionsHouseMock.reset();
    coinJoin.reset();
  }

  function test_increaseBidSize() public {
    vm.startPrank(alice);
    address _surplusAuctionHouse = address(surplusActionsHouseMock);
    uint256 _auctionId = 1;
    uint256 _bidAmount = 100;
    surplusActionsHouseMock.setHighBidder(address(proxy));
    surplusActionsHouseMock.protocolTokenContract().approve(address(proxy), 10 ether);
    proxy.execute(
      address(surplusActionsHouseMock.protocolTokenContract()),
      abi.encodeWithSignature('approve(address,uint256)', _surplusAuctionHouse, 10 ether)
    );

    proxy.execute(
      address(surplusBidActions),
      abi.encodeWithSignature('increaseBidSize(address,uint256,uint256)', _surplusAuctionHouse, _auctionId, _bidAmount)
    );

    assertEq(surplusActionsHouseMock.wasIncreaseBidSizeCalled(), true);
    assertEq(surplusActionsHouseMock.wasSettleAuctionCalled(), false);
  }

  function test_settleAuctionWithSafeModificationTrue() public {
    vm.startPrank(alice);
    address _coinJoin = address(coinJoin);
    address _surplusAuctionHouse = address(surplusActionsHouseMock);
    uint256 _auctionId = 1;
    SafeEngineMock safeEngine = SafeEngineMock(coinJoin.safeEngine());
    safeEngine._mock_setCanModifySAFE(true);
    proxy.execute(
      address(surplusBidActions),
      abi.encodeWithSignature('settleAuction(address,address,uint256)', _coinJoin, _surplusAuctionHouse, _auctionId)
    );

    assertEq(surplusActionsHouseMock.wasIncreaseBidSizeCalled(), false);
    assertEq(surplusActionsHouseMock.wasSettleAuctionCalled(), true);
    assertEq(coinJoin.wasExitCalled(), true);
    assertEq(safeEngine.wasApproveSAFEModificationCalled(), false);
  }

  function test_settleAuctionWithSafeModificationFalse() public {
    vm.startPrank(alice);
    address _coinJoin = address(coinJoin);
    address _surplusAuctionHouse = address(surplusActionsHouseMock);
    uint256 _auctionId = 1;
    SafeEngineMock safeEngine = SafeEngineMock(coinJoin.safeEngine());
    safeEngine._mock_setCanModifySAFE(false);
    proxy.execute(
      address(surplusBidActions),
      abi.encodeWithSignature('settleAuction(address,address,uint256)', _coinJoin, _surplusAuctionHouse, _auctionId)
    );

    assertEq(surplusActionsHouseMock.wasIncreaseBidSizeCalled(), false);
    assertEq(surplusActionsHouseMock.wasSettleAuctionCalled(), true);
    assertEq(coinJoin.wasExitCalled(), true);
    assertEq(safeEngine.wasApproveSAFEModificationCalled(), true);
  }
}
