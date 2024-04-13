// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {DebtBidActions, IDebtAuctionHouse} from '@contracts/proxies/actions/DebtBidActions.sol';
import {CoinJoinMock, SafeEngineMock, DebtAuctionHouseMock} from '@test/mocks/ActionsMocks.sol';

contract DebtBidActionsTest is ActionBaseTest {
  DebtBidActions public debtBidActions = new DebtBidActions();
  DebtAuctionHouseMock public debtAuctionHouseMock = new DebtAuctionHouseMock();
  SafeEngineMock public safeEngine = new SafeEngineMock();
  CoinJoinMock public coinJoin = new CoinJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
    debtAuctionHouseMock.reset();
    safeEngine.reset();
    coinJoin.reset();
  }

  function test_decreaseSoldAmount() public {
    vm.startPrank(alice);
    debtAuctionHouseMock._mock_setAuction(1, 1, address(alice), 1, 1);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    proxy.execute(
      address(debtBidActions),
      abi.encodeWithSignature(
        'decreaseSoldAmount(address,address,uint256,uint256)', address(coinJoin), address(debtAuctionHouseMock), 1, 1
      )
    );

    assertTrue(coinJoin.wasJoinCalled());
  }

  function test_settleAuction() public {
    vm.startPrank(alice);
    debtAuctionHouseMock._mock_setAuction(1, 1, address(alice), 1, 1);
    SafeEngineMock(coinJoin.safeEngine())._mock_setCoinBalance(1 ether);
    proxy.execute(
      address(debtBidActions),
      abi.encodeWithSignature(
        'settleAuction(address,address,uint256)', address(coinJoin), address(debtAuctionHouseMock), 1
      )
    );

    assertTrue(coinJoin.wasExitCalled());
  }

  function test_collectProtocolTokens() public {
    vm.startPrank(alice);
    bytes memory resp = proxy.execute(
      address(debtBidActions), abi.encodeWithSignature('collectProtocolTokens(address)', address(coinJoin.systemCoin()))
    );
    assertTrue(resp.length == 0);
  }
}
