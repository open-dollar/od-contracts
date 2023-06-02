// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'ds-test/test.sol';
import {DSToken as DSDelegateToken} from '@contracts/for-test/DSToken.sol';
import {DisableableForTest} from '@contracts/for-test/DisableableForTest.sol';

import {PostSettlementSurplusAuctionHouse} from '@contracts/settlement/PostSettlementSurplusAuctionHouse.sol';
import {SettlementSurplusAuctioneer} from '@contracts/settlement/SettlementSurplusAuctioneer.sol';
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {AccountingEngine} from '@contracts/AccountingEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {Coin} from '@contracts/utils/Coin.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract SingleSettlementSurplusAuctioneerTest is DSTest {
  Hevm hevm;

  SettlementSurplusAuctioneer surplusAuctioneer;
  PostSettlementSurplusAuctionHouse surplusAuctionHouse;
  AccountingEngine accountingEngine;
  SAFEEngine safeEngine;
  DSDelegateToken protocolToken;

  uint256 constant ONE = 10 ** 27;

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * ONE;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    DisableableForTest disableable1 = new DisableableForTest();
    DisableableForTest disableable2 = new DisableableForTest();

    safeEngine = new SAFEEngine();
    accountingEngine = new AccountingEngine(address(safeEngine), address(disableable1), address(disableable2));
    protocolToken = new DSDelegateToken('', '');

    disableable1.addAuthorization(address(accountingEngine));
    disableable2.addAuthorization(address(accountingEngine));
    accountingEngine.modifyParameters('surplusAmount', abi.encode(100 ether * 10 ** 9));
    accountingEngine.modifyParameters('surplusDelay', abi.encode(3600));

    surplusAuctionHouse = new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken));
    surplusAuctioneer = new SettlementSurplusAuctioneer(address(accountingEngine), address(surplusAuctionHouse));
    surplusAuctionHouse.addAuthorization(address(surplusAuctioneer));

    safeEngine.approveSAFEModification(address(surplusAuctionHouse));
    protocolToken.approve(address(surplusAuctionHouse));

    safeEngine.createUnbackedDebt(address(this), address(this), 1000 ether);

    protocolToken.mint(1000 ether);
    protocolToken.setOwner(address(surplusAuctionHouse));
  }

  function test_modify_parameters() public {
    surplusAuctioneer.modifyParameters('accountingEngine', abi.encode(0x1234));
    surplusAuctioneer.modifyParameters('surplusAuctionHouse', abi.encode(0x1234));

    assertEq(safeEngine.safeRights(address(surplusAuctioneer), address(surplusAuctionHouse)), 0);
    assertEq(safeEngine.safeRights(address(surplusAuctioneer), address(0x1234)), 1);

    assertTrue(address(surplusAuctioneer.accountingEngine()) == address(0x1234));
    assertTrue(address(surplusAuctioneer.surplusAuctionHouse()) == address(0x1234));
  }

  function testFail_auction_when_accounting_still_enabled() public {
    safeEngine.createUnbackedDebt(address(0), address(surplusAuctioneer), rad(100 ether * 10 ** 9));
    surplusAuctioneer.auctionSurplus();
  }

  function testFail_auction_without_waiting_for_delay() public {
    accountingEngine.disableContract();
    safeEngine.createUnbackedDebt(address(0), address(surplusAuctioneer), rad(500 ether * 10 ** 9));
    surplusAuctioneer.auctionSurplus();
    surplusAuctioneer.auctionSurplus();
  }

  function test_auction_surplus() public {
    accountingEngine.disableContract();
    safeEngine.createUnbackedDebt(address(0), address(surplusAuctioneer), rad(500 ether * 10 ** 9));
    uint256 id = surplusAuctioneer.auctionSurplus();
    assertEq(id, 1);
    (uint256 bidAmount, uint256 amountToSell, address highBidder,,) = surplusAuctionHouse.bids(id);
    assertEq(bidAmount, 0);
    assertEq(amountToSell, 100 ether * 10 ** 9);
    assertEq(highBidder, address(surplusAuctioneer));
  }

  function test_trigger_second_auction_after_delay() public {
    accountingEngine.disableContract();
    safeEngine.createUnbackedDebt(address(0), address(surplusAuctioneer), rad(500 ether * 10 ** 9));
    surplusAuctioneer.auctionSurplus();
    hevm.warp(block.timestamp + accountingEngine.params().surplusDelay);
    surplusAuctioneer.auctionSurplus();
  }

  function test_nothing_to_auction() public {
    accountingEngine.disableContract();
    safeEngine.createUnbackedDebt(address(0), address(surplusAuctioneer), rad(1));
    surplusAuctioneer.auctionSurplus();
    hevm.warp(block.timestamp + accountingEngine.params().surplusDelay);
    uint256 id = surplusAuctioneer.auctionSurplus();
    assertEq(id, 0);
    (uint256 bidAmount, uint256 amountToSell, address highBidder,,) = surplusAuctionHouse.bids(2);
    assertEq(bidAmount, 0);
    assertEq(amountToSell, 0);
    assertEq(highBidder, address(0));
  }
}
