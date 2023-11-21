// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'ds-test/test.sol';
import {CoinForTest} from '@test/mocks/CoinForTest.sol';
import {DisableableForTest} from '@test/mocks/DisableableForTest.sol';
import {
  IPostSettlementSurplusAuctionHouse,
  PostSettlementSurplusAuctionHouse
} from '@contracts/settlement/PostSettlementSurplusAuctionHouse.sol';
import {SettlementSurplusAuctioneer} from '@contracts/settlement/SettlementSurplusAuctioneer.sol';
import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {IAccountingEngine, AccountingEngine} from '@contracts/AccountingEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract SingleSettlementSurplusAuctioneerTest is DSTest {
  Hevm hevm;

  SettlementSurplusAuctioneer surplusAuctioneer;
  PostSettlementSurplusAuctionHouse surplusAuctionHouse;
  AccountingEngine accountingEngine;
  SAFEEngine safeEngine;
  CoinForTest protocolToken;

  uint256 constant ONE = 10 ** 27;

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * ONE;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    DisableableForTest disableable1 = new DisableableForTest();
    DisableableForTest disableable2 = new DisableableForTest();

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});

    safeEngine = new SAFEEngine(_safeEngineParams);

    IAccountingEngine.AccountingEngineParams memory _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0,
      surplusDelay: 3600,
      popDebtDelay: 0,
      disableCooldown: 0,
      surplusAmount: 100 ether * 10 ** 9,
      surplusBuffer: 0,
      debtAuctionMintedTokens: 0,
      debtAuctionBidSize: 0
    });

    accountingEngine =
      new AccountingEngine(address(safeEngine), address(disableable1), address(disableable2), _accountingEngineParams);
    protocolToken = new CoinForTest('', '');

    disableable1.addAuthorization(address(accountingEngine));
    disableable2.addAuthorization(address(accountingEngine));

    IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _pssahParams = IPostSettlementSurplusAuctionHouse
      .PostSettlementSAHParams({bidIncrease: 1.05e18, bidDuration: 3 hours, totalAuctionLength: 2 days});
    surplusAuctionHouse =
      new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken), _pssahParams);
    surplusAuctioneer = new SettlementSurplusAuctioneer(address(accountingEngine), address(surplusAuctionHouse));
    surplusAuctionHouse.addAuthorization(address(surplusAuctioneer));

    safeEngine.approveSAFEModification(address(surplusAuctionHouse));

    safeEngine.createUnbackedDebt(address(this), address(this), 1000 ether);

    protocolToken.mint(1000 ether);
    protocolToken.approve(address(surplusAuctionHouse), type(uint256).max);
  }

  function test_modify_parameters() public {
    surplusAuctioneer.modifyParameters('accountingEngine', abi.encode(0x1234));
    surplusAuctioneer.modifyParameters('surplusAuctionHouse', abi.encode(0x1234));

    assert(safeEngine.safeRights(address(surplusAuctioneer), address(surplusAuctionHouse)) == false);
    assert(safeEngine.safeRights(address(surplusAuctioneer), address(0x1234)) == true);

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
    IPostSettlementSurplusAuctionHouse.Auction memory _auction = surplusAuctionHouse.auctions(id);
    assertEq(_auction.bidAmount, 0);
    assertEq(_auction.amountToSell, 100 ether * 10 ** 9);
    assertEq(_auction.highBidder, address(surplusAuctioneer));
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
    IPostSettlementSurplusAuctionHouse.Auction memory _auction = surplusAuctionHouse.auctions(2);
    assertEq(_auction.bidAmount, 0);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.highBidder, address(0));
  }
}
