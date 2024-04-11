// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {DebtBidActions, IDebtAuctionHouse} from '@contracts/proxies/actions/DebtBidActions.sol';
import {CoinJoinMock, SafeEngineMock} from './SurplusBidActions.t.sol';

contract DebtAuctionHouseMock {
  bool public wasDecreaseSoldAmountCalled;
  bool public wasSettleAuctionCalled;
  IDebtAuctionHouse.Auction public auction;

  function reset() external {
    wasDecreaseSoldAmountCalled = false;
    wasSettleAuctionCalled = false;
  }

  function auctions(uint256 _id) external view returns (IDebtAuctionHouse.Auction memory _auction) {
    return auction;
  }

  function _mock_setAuction(
    uint256 bidAmount,
    uint256 amountToSell,
    address highBidder,
    uint256 bidExpiry,
    uint256 auctionDeadline
  ) external {
    auction = IDebtAuctionHouse.Auction(bidAmount, amountToSell, highBidder, bidExpiry, auctionDeadline);
  }

  function decreaseSoldAmount(uint256 _id, uint256 _amountToBuy) external {
    wasDecreaseSoldAmountCalled = true;
  }

  function settleAuction(uint256 _id) external {
    wasSettleAuctionCalled = true;
  }
}

contract DebtBidActionsTest is ActionBaseTest {
  DebtBidActions public debtBidActions = new DebtBidActions();
  DebtAuctionHouseMock public debtAuctionHouseMock = new DebtAuctionHouseMock();
  SafeEngineMock public safeEngine = new SafeEngineMock();
  CoinJoinMock public coinJoin = new CoinJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function test_decreaseSoldAmount() public {
    debtAuctionHouseMock.reset();
    debtAuctionHouseMock._mock_setAuction(1, 1, address(alice), 1, 1);
    vm.startPrank(alice);

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
    debtAuctionHouseMock.reset();
    debtAuctionHouseMock._mock_setAuction(1, 1, address(alice), 1, 1);
    SafeEngineMock safeEngine = SafeEngineMock(coinJoin.safeEngine());
    safeEngine.mock_setCoinBalance(100);
    vm.startPrank(alice);

    proxy.execute(
      address(debtBidActions),
      abi.encodeWithSignature(
        'settleAuction(address,address,uint256)', address(coinJoin), address(debtAuctionHouseMock), 1
      )
    );

    assertTrue(coinJoin.wasExitCalled());
  }
}
