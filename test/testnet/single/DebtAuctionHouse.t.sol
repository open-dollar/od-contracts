// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {DSTest} from 'ds-test/test.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

import {IDebtAuctionHouse, DebtAuctionHouse} from '@contracts/DebtAuctionHouse.sol';
import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract Guy {
  DebtAuctionHouse debtAuctionHouse;

  constructor(DebtAuctionHouse debtAuctionHouse_) {
    debtAuctionHouse = debtAuctionHouse_;
    debtAuctionHouse.safeEngine().approveSAFEModification(address(debtAuctionHouse));
    debtAuctionHouse.protocolToken().approve(address(debtAuctionHouse), type(uint256).max);
  }

  function decreaseSoldAmount(uint256 id, uint256 amountToBuy) public {
    debtAuctionHouse.decreaseSoldAmount(id, amountToBuy);
  }

  function settleAuction(uint256 id) public {
    debtAuctionHouse.settleAuction(id);
  }

  function try_decreaseSoldAmount(uint256 id, uint256 amountToBuy) public returns (bool ok) {
    string memory sig = 'decreaseSoldAmount(uint256,uint256)';
    (ok,) = address(debtAuctionHouse).call(abi.encodeWithSignature(sig, id, amountToBuy));
  }

  function try_settleAuction(uint256 id) public returns (bool ok) {
    string memory sig = 'settleAuction(uint256)';
    (ok,) = address(debtAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }

  function try_restart_auction(uint256 id) public returns (bool ok) {
    string memory sig = 'restartAuction(uint256)';
    (ok,) = address(debtAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }
}

contract DummyAccountingEngine {
  uint256 public totalOnAuctionDebt;

  function startAuction(
    DebtAuctionHouse debtAuctionHouse,
    uint256 amountToSell,
    uint256 initialBid
  ) external returns (uint256) {
    totalOnAuctionDebt += initialBid;
    uint256 id = debtAuctionHouse.startAuction(address(this), amountToSell, initialBid);
    return id;
  }

  function cancelAuctionedDebtWithSurplus(uint256 rad) external {
    totalOnAuctionDebt -= rad;
  }

  function disableContract(IDisableable target) external {
    target.disableContract();
  }
}

contract SingleDebtAuctionHouseTest is DSTest {
  Hevm hevm;

  DebtAuctionHouse debtAuctionHouse;
  SAFEEngine safeEngine;
  ProtocolToken protocolToken;
  DummyAccountingEngine accountingEngine;

  address ali;
  address bob;

  function cancelAuctionedDebtWithSurplus(uint256) public pure {} // arbitrary callback

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);
    protocolToken = new ProtocolToken();

    IDebtAuctionHouse.DebtAuctionHouseParams memory _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18,
      amountSoldIncrease: 1.5e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });

    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken), _debtAuctionHouseParams);

    ali = address(new Guy(debtAuctionHouse));
    bob = address(new Guy(debtAuctionHouse));
    accountingEngine = new DummyAccountingEngine();

    debtAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.removeAuthorization(address(this));

    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    safeEngine.addAuthorization(address(debtAuctionHouse));

    protocolToken.addAuthorization(address(debtAuctionHouse));

    safeEngine.createUnbackedDebt(address(this), address(this), 1000 ether);

    safeEngine.transferInternalCoins(address(this), ali, 200 ether);
    safeEngine.transferInternalCoins(address(this), bob, 200 ether);
  }

  function test_startAuction() public {
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0);
    assertEq(protocolToken.balanceOf(address(accountingEngine)), 0 ether);
    uint256 id = accountingEngine.startAuction(debtAuctionHouse, /*amountToSell*/ 200 ether, /*bid*/ 5000 ether);
    assertEq(debtAuctionHouse.activeDebtAuctions(), id);
    // no value transferred
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0);
    assertEq(protocolToken.balanceOf(address(accountingEngine)), 0 ether);
    // auction created with appropriate values
    assertEq(debtAuctionHouse.auctionsStarted(), id);
    IDebtAuctionHouse.Auction memory _auction = debtAuctionHouse.auctions(id);
    assertEq(_auction.bidAmount, 5000 ether);
    assertEq(_auction.amountToSell, 200 ether);
    assertTrue(_auction.highBidder == address(accountingEngine));
    assertEq(_auction.bidExpiry, 0);
    assertEq(_auction.auctionDeadline, block.timestamp + debtAuctionHouse.params().totalAuctionLength);
  }

  function test_decreaseSoldAmount() public {
    uint256 id = accountingEngine.startAuction(debtAuctionHouse, /*amountToSell*/ 200 ether, /*bid*/ 10 ether);

    Guy(ali).decreaseSoldAmount(id, 100 ether);
    // bid taken from bidder
    assertEq(safeEngine.coinBalance(ali), 190 ether);
    // accountingEngine receives payment
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 10 ether);
    assertEq(accountingEngine.totalOnAuctionDebt(), 0 ether);

    Guy(bob).decreaseSoldAmount(id, 80 ether);
    // bid taken from bidder
    assertEq(safeEngine.coinBalance(bob), 190 ether);
    // prev bidder refunded
    assertEq(safeEngine.coinBalance(ali), 200 ether);
    // accountingEngine receives no more
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 10 ether);

    hevm.warp(block.timestamp + 5 weeks);
    assertEq(protocolToken.totalSupply(), 0 ether);
    Guy(bob).settleAuction(id);
    // marked auction in the accounting engine
    assertEq(debtAuctionHouse.activeDebtAuctions(), 0);
    // tokens minted on demand
    assertEq(protocolToken.totalSupply(), 80 ether);
    // bob gets the winnings
    assertEq(protocolToken.balanceOf(bob), 80 ether);
  }

  function test_dent_totalOnAuctionDebt_less_than_bid() public {
    uint256 id = accountingEngine.startAuction(debtAuctionHouse, /*amountToSell*/ 200 ether, /*bid*/ 10 ether);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0 ether);

    accountingEngine.cancelAuctionedDebtWithSurplus(1 ether);
    assertEq(accountingEngine.totalOnAuctionDebt(), 9 ether);

    Guy(ali).decreaseSoldAmount(id, 100 ether);
    // bid taken from bidder
    assertEq(safeEngine.coinBalance(ali), 190 ether);
    // accountingEngine receives payment
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 10 ether);
    assertEq(accountingEngine.totalOnAuctionDebt(), 0 ether);

    Guy(bob).decreaseSoldAmount(id, 80 ether);
    // bid taken from bidder
    assertEq(safeEngine.coinBalance(bob), 190 ether);
    // prev bidder refunded
    assertEq(safeEngine.coinBalance(ali), 200 ether);
    // accountingEngine receives no more
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 10 ether);

    hevm.warp(block.timestamp + 5 weeks);
    assertEq(protocolToken.totalSupply(), 0 ether);
    Guy(bob).settleAuction(id);
    // marked auction in the accounting engine
    assertEq(debtAuctionHouse.activeDebtAuctions(), 0);
    // tokens minted on demand
    assertEq(protocolToken.totalSupply(), 80 ether);
    // bob gets the winnings
    assertEq(protocolToken.balanceOf(bob), 80 ether);
  }

  function test_restart_auction() public {
    // start an auction
    uint256 id = accountingEngine.startAuction(debtAuctionHouse, /*amountToSell*/ 200 ether, /*bid*/ 10 ether);
    // check no restarting
    assertTrue(!Guy(ali).try_restart_auction(id));
    // run past the end
    hevm.warp(block.timestamp + 2 weeks);
    // check not biddable
    assertTrue(!Guy(ali).try_decreaseSoldAmount(id, 100 ether));
    assertTrue(Guy(ali).try_restart_auction(id));
    // left auction in the accounting engine
    assertEq(debtAuctionHouse.activeDebtAuctions(), id);
    // check biddable
    uint256 _amountToSell = debtAuctionHouse.auctions(id).amountToSell;
    // restart should increase the amountToSell by pad (50%) and restart the auction
    assertEq(_amountToSell, 300 ether);
    assertTrue(Guy(ali).try_decreaseSoldAmount(id, 100 ether));
  }

  function test_no_deal_after_settlement() public {
    // if there are no bids and the auction ends, then it should not
    // be refundable to the creator. Rather, it restarts indefinitely.
    uint256 id = accountingEngine.startAuction(debtAuctionHouse, /*amountToSell*/ 200 ether, /*bid*/ 10 ether);
    assertTrue(!Guy(ali).try_settleAuction(id));
    hevm.warp(block.timestamp + 2 weeks);
    assertTrue(!Guy(ali).try_settleAuction(id));
    assertTrue(Guy(ali).try_restart_auction(id));
    // left auction in the accounting engine
    assertEq(debtAuctionHouse.activeDebtAuctions(), id);
    assertTrue(!Guy(ali).try_settleAuction(id));
  }

  function test_terminate_prematurely() public {
    // terminating the auction prematurely should refund the last bidder's coin, credit a
    // corresponding amount of sin to the caller of cage, and delete the auction.
    // in practice, accountingEngine == (caller of cage)
    uint256 id = accountingEngine.startAuction(debtAuctionHouse, /*amountToSell*/ 200 ether, /*bid*/ 10 ether);

    // confrim initial state expectations
    assertEq(safeEngine.coinBalance(ali), 200 ether);
    assertEq(safeEngine.coinBalance(bob), 200 ether);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), 0);

    Guy(ali).decreaseSoldAmount(id, 100 ether);
    Guy(bob).decreaseSoldAmount(id, 80 ether);

    // confirm the proper state updates have occurred
    assertEq(safeEngine.coinBalance(ali), 200 ether); // ali's coin balance is unchanged
    assertEq(safeEngine.coinBalance(bob), 190 ether);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 10 ether);
    assertEq(safeEngine.debtBalance(address(this)), 1000 ether);

    accountingEngine.disableContract(debtAuctionHouse);
    assertEq(debtAuctionHouse.activeDebtAuctions(), 0);
    debtAuctionHouse.terminateAuctionPrematurely(id);

    // deleted auction from the accounting engine
    assertEq(debtAuctionHouse.activeDebtAuctions(), 0);
    // confirm final state
    assertEq(safeEngine.coinBalance(ali), 200 ether);
    assertEq(safeEngine.coinBalance(bob), 200 ether); // bob's bid has been refunded
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 10 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), 10 ether); // sin assigned to caller of disableContract()
    IDebtAuctionHouse.Auction memory _auction = debtAuctionHouse.auctions(id);
    assertEq(_auction.bidAmount, 0);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.highBidder, address(0));
    assertEq(_auction.bidExpiry, 0);
    assertEq(_auction.auctionDeadline, 0);
  }

  function test_terminate_prematurely_no_bids() public {
    // with no bidder to refund, terminating the auction prematurely should simply create equal
    // amounts of coin (credited to the accountingEngine) and sin (credited to the caller of cage)
    // in practice, accountingEngine == (caller of cage)
    uint256 id = accountingEngine.startAuction(debtAuctionHouse, /*amountToSell*/ 200 ether, /*bid*/ 10 ether);

    // confrim initial state expectations
    assertEq(safeEngine.coinBalance(ali), 200 ether);
    assertEq(safeEngine.coinBalance(bob), 200 ether);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 0);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), 0);

    accountingEngine.disableContract(debtAuctionHouse);
    debtAuctionHouse.terminateAuctionPrematurely(id);

    // deleted auction from the accounting engine
    assertEq(debtAuctionHouse.activeDebtAuctions(), 0);
    // confirm final state
    assertEq(safeEngine.coinBalance(ali), 200 ether);
    assertEq(safeEngine.coinBalance(bob), 200 ether);
    assertEq(safeEngine.coinBalance(address(accountingEngine)), 10 ether);
    assertEq(safeEngine.debtBalance(address(accountingEngine)), 10 ether); // sin assigned to caller of disableContract()
    IDebtAuctionHouse.Auction memory _auction = debtAuctionHouse.auctions(id);
    assertEq(_auction.bidAmount, 0);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.highBidder, address(0));
    assertEq(_auction.bidExpiry, 0);
    assertEq(_auction.auctionDeadline, 0);
  }
}
