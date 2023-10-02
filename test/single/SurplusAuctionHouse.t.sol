// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'ds-test/test.sol';

import {ISurplusAuctionHouse, SurplusAuctionHouse} from '@contracts/SurplusAuctionHouse.sol';
import {
  IPostSettlementSurplusAuctionHouse,
  PostSettlementSurplusAuctionHouse
} from '@contracts/settlement/PostSettlementSurplusAuctionHouse.sol';
import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';

import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract GuyBurningSurplusAuction {
  SurplusAuctionHouse surplusAuctionHouse;

  constructor(SurplusAuctionHouse surplusAuctionHouse_) {
    surplusAuctionHouse = surplusAuctionHouse_;
    surplusAuctionHouse.safeEngine().approveSAFEModification(address(surplusAuctionHouse));
    surplusAuctionHouse.protocolToken().approve(address(surplusAuctionHouse), type(uint256).max);
  }

  function increaseBidSize(uint256 id, uint256 bid) public {
    surplusAuctionHouse.increaseBidSize(id, bid);
  }

  function settleAuction(uint256 id) public {
    surplusAuctionHouse.settleAuction(id);
  }

  function try_increaseBidSize(uint256 id, uint256 bid) public returns (bool ok) {
    string memory sig = 'increaseBidSize(uint256,uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id, bid));
  }

  function try_settleAuction(uint256 id) public returns (bool ok) {
    string memory sig = 'settleAuction(uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }

  function try_restartAuction(uint256 id) public returns (bool ok) {
    string memory sig = 'restartAuction(uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }
}

contract GuyRecyclingSurplusAuction {
  SurplusAuctionHouse surplusAuctionHouse;

  constructor(SurplusAuctionHouse surplusAuctionHouse_) {
    surplusAuctionHouse = surplusAuctionHouse_;
    surplusAuctionHouse.safeEngine().approveSAFEModification(address(surplusAuctionHouse));
    surplusAuctionHouse.protocolToken().approve(address(surplusAuctionHouse), type(uint256).max);
  }

  function increaseBidSize(uint256 id, uint256 bid) public {
    surplusAuctionHouse.increaseBidSize(id, bid);
  }

  function settleAuction(uint256 id) public {
    surplusAuctionHouse.settleAuction(id);
  }

  function try_increaseBidSize(uint256 id, uint256 bid) public returns (bool ok) {
    string memory sig = 'increaseBidSize(uint256,uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id, bid));
  }

  function try_settleAuction(uint256 id) public returns (bool ok) {
    string memory sig = 'settleAuction(uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }

  function try_restartAuction(uint256 id) public returns (bool ok) {
    string memory sig = 'restartAuction(uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }
}

contract GuyPostSurplusAuction {
  PostSettlementSurplusAuctionHouse surplusAuctionHouse;

  constructor(PostSettlementSurplusAuctionHouse surplusAuctionHouse_) {
    surplusAuctionHouse = surplusAuctionHouse_;
    surplusAuctionHouse.safeEngine().approveSAFEModification(address(surplusAuctionHouse));
    surplusAuctionHouse.protocolToken().approve(address(surplusAuctionHouse), type(uint256).max);
  }

  function increaseBidSize(uint256 id, uint256 bid) public {
    surplusAuctionHouse.increaseBidSize(id, bid);
  }

  function settleAuction(uint256 id) public {
    surplusAuctionHouse.settleAuction(id);
  }

  function try_increaseBidSize(uint256 id, uint256 bid) public returns (bool ok) {
    string memory sig = 'increaseBidSize(uint256,uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id, bid));
  }

  function try_settleAuction(uint256 id) public returns (bool ok) {
    string memory sig = 'settleAuction(uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }

  function try_restartAuction(uint256 id) public returns (bool ok) {
    string memory sig = 'restartAuction(uint256)';
    (ok,) = address(surplusAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }
}

contract SingleBurningSurplusAuctionHouseTest is DSTest {
  Hevm hevm;

  SurplusAuctionHouse surplusAuctionHouse;
  SAFEEngine safeEngine;
  ProtocolToken protocolToken;

  address ali;
  address bob;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);
    protocolToken = new ProtocolToken('', '');

    ISurplusAuctionHouse.SurplusAuctionHouseParams memory _sahParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.05e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days,
      bidReceiver: address(0x123),
      recyclingPercentage: 0
    });
    surplusAuctionHouse = new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _sahParams);

    ali = address(new GuyBurningSurplusAuction(surplusAuctionHouse));
    bob = address(new GuyBurningSurplusAuction(surplusAuctionHouse));

    safeEngine.approveSAFEModification(address(surplusAuctionHouse));

    safeEngine.createUnbackedDebt(address(this), address(this), 1000 ether);

    protocolToken.mint(address(this), 1000 ether);
    protocolToken.transfer(ali, 200 ether);
    protocolToken.transfer(bob, 200 ether);
  }

  function test_start_auction() public {
    assertEq(safeEngine.coinBalance(address(this)), 1000 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 100 ether);
  }

  function test_increase_bid_same_bidder() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    GuyBurningSurplusAuction(ali).increaseBidSize(id, 190 ether);
    assertEq(protocolToken.balanceOf(ali), 10 ether);
    GuyBurningSurplusAuction(ali).increaseBidSize(id, 200 ether);
    assertEq(protocolToken.balanceOf(ali), 0);
  }

  function test_increaseBidSize() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyBurningSurplusAuction(ali).increaseBidSize(id, 1 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(ali), 199 ether);
    // payment remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 1 ether);

    GuyBurningSurplusAuction(bob).increaseBidSize(id, 2 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(bob), 198 ether);
    // prev bidder refunded
    assertEq(protocolToken.balanceOf(ali), 200 ether);
    // excess remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 2 ether);

    hevm.warp(block.timestamp + 5 weeks);
    GuyBurningSurplusAuction(bob).settleAuction(id);
    // high bidder gets the amount sold
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    assertEq(safeEngine.coinBalance(bob), 100 ether);
    // income is burned
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 0 ether);
  }

  function test_bid_increase() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertTrue(GuyBurningSurplusAuction(ali).try_increaseBidSize(id, 1.0 ether));
    assertTrue(!GuyBurningSurplusAuction(bob).try_increaseBidSize(id, 1.01 ether));
    // high bidder is subject to beg
    assertTrue(!GuyBurningSurplusAuction(ali).try_increaseBidSize(id, 1.01 ether));
    assertTrue(GuyBurningSurplusAuction(bob).try_increaseBidSize(id, 1.07 ether));
  }

  function test_restart_auction() public {
    // start an auction
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // check no tick
    assertTrue(!GuyBurningSurplusAuction(ali).try_restartAuction(id));
    // run past the end
    hevm.warp(block.timestamp + 2 weeks);
    // check not biddable
    assertTrue(!GuyBurningSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
    assertTrue(GuyBurningSurplusAuction(ali).try_restartAuction(id));
    // check biddable
    assertTrue(GuyBurningSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
  }

  function testFail_terminate_prematurely() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyBurningSurplusAuction(ali).increaseBidSize(id, 1 ether);
    surplusAuctionHouse.terminateAuctionPrematurely(id);
  }

  function test_terminate_prematurely() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyBurningSurplusAuction(ali).increaseBidSize(id, 1 ether);
    // Shutdown
    surplusAuctionHouse.disableContract();
    surplusAuctionHouse.terminateAuctionPrematurely(id);
  }
}

contract SingleRecyclingSurplusAuctionHouseTest is DSTest {
  Hevm hevm;

  SurplusAuctionHouse surplusAuctionHouse;
  SAFEEngine safeEngine;
  ProtocolToken protocolToken;

  address ali;
  address bob;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);
    protocolToken = new ProtocolToken('', '');

    ISurplusAuctionHouse.SurplusAuctionHouseParams memory _sahParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.05e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days,
      bidReceiver: address(0x123),
      recyclingPercentage: 1e18
    });
    surplusAuctionHouse = new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _sahParams);

    ali = address(new GuyRecyclingSurplusAuction(surplusAuctionHouse));
    bob = address(new GuyRecyclingSurplusAuction(surplusAuctionHouse));

    safeEngine.approveSAFEModification(address(surplusAuctionHouse));

    safeEngine.createUnbackedDebt(address(this), address(this), 1000 ether);

    protocolToken.mint(address(this), 1000 ether);

    protocolToken.transfer(ali, 200 ether);
    protocolToken.transfer(bob, 200 ether);
  }

  function test_start_auction() public {
    assertEq(safeEngine.coinBalance(address(this)), 1000 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 100 ether);
  }

  function testFail_start_auction_when_prot_token_receiver_null() public {
    surplusAuctionHouse.modifyParameters('bidReceiver', abi.encode(0));
    surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
  }

  function test_increase_bid_same_bidder() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 190 ether);
    assertEq(protocolToken.balanceOf(ali), 10 ether);
    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 200 ether);
    assertEq(protocolToken.balanceOf(ali), 0);
  }

  function test_increaseBidSize() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 1 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(ali), 199 ether);
    // payment remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 1 ether);

    GuyRecyclingSurplusAuction(bob).increaseBidSize(id, 2 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(bob), 198 ether);
    // prev bidder refunded
    assertEq(protocolToken.balanceOf(ali), 200 ether);
    // excess remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 2 ether);

    hevm.warp(block.timestamp + 5 weeks);
    GuyRecyclingSurplusAuction(bob).settleAuction(id);
    // high bidder gets the amount sold
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    assertEq(safeEngine.coinBalance(bob), 100 ether);
    // income is transferred to address(0)
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 0 ether);
    assertEq(protocolToken.balanceOf(surplusAuctionHouse.params().bidReceiver), 2 ether);
  }

  function test_bid_increase() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertTrue(GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1.0 ether));
    assertTrue(!GuyRecyclingSurplusAuction(bob).try_increaseBidSize(id, 1.01 ether));
    // high bidder is subject to beg
    assertTrue(!GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1.01 ether));
    assertTrue(GuyRecyclingSurplusAuction(bob).try_increaseBidSize(id, 1.07 ether));
  }

  function test_restart_auction() public {
    // start an auction
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // check no tick
    assertTrue(!GuyRecyclingSurplusAuction(ali).try_restartAuction(id));
    // run past the end
    hevm.warp(block.timestamp + 2 weeks);
    // check not biddable
    assertTrue(!GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
    assertTrue(GuyRecyclingSurplusAuction(ali).try_restartAuction(id));
    // check biddable
    assertTrue(GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
  }

  function testFail_terminate_prematurely() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 1 ether);
    surplusAuctionHouse.terminateAuctionPrematurely(id);
  }

  function test_terminate_prematurely() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 1 ether);
    // Shutdown
    surplusAuctionHouse.disableContract();
    surplusAuctionHouse.terminateAuctionPrematurely(id);
  }
}

contract SingleMixedStratSurplusAuctionHouseTest is DSTest {
  Hevm hevm;

  SurplusAuctionHouse surplusAuctionHouse;
  SAFEEngine safeEngine;
  ProtocolToken protocolToken;

  address ali;
  address bob;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);
    protocolToken = new ProtocolToken('', '');

    ISurplusAuctionHouse.SurplusAuctionHouseParams memory _sahParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.05e18,
      bidDuration: 3 hours,
      totalAuctionLength: 2 days,
      bidReceiver: address(0x123),
      recyclingPercentage: 0.5e18
    });
    surplusAuctionHouse = new SurplusAuctionHouse(address(safeEngine), address(protocolToken), _sahParams);

    ali = address(new GuyRecyclingSurplusAuction(surplusAuctionHouse));
    bob = address(new GuyRecyclingSurplusAuction(surplusAuctionHouse));

    safeEngine.approveSAFEModification(address(surplusAuctionHouse));

    safeEngine.createUnbackedDebt(address(this), address(this), 1000 ether);

    protocolToken.mint(address(this), 1000 ether);

    protocolToken.transfer(ali, 200 ether);
    protocolToken.transfer(bob, 200 ether);
  }

  function test_start_auction() public {
    assertEq(safeEngine.coinBalance(address(this)), 1000 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 100 ether);
  }

  function testFail_start_auction_when_prot_token_receiver_null() public {
    surplusAuctionHouse.modifyParameters('bidReceiver', abi.encode(0));
    surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
  }

  function test_increase_bid_same_bidder() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 190 ether);
    assertEq(protocolToken.balanceOf(ali), 10 ether);
    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 200 ether);
    assertEq(protocolToken.balanceOf(ali), 0);
  }

  function test_increaseBidSize() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 1 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(ali), 199 ether);
    // payment remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 1 ether);

    GuyRecyclingSurplusAuction(bob).increaseBidSize(id, 2 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(bob), 198 ether);
    // prev bidder refunded
    assertEq(protocolToken.balanceOf(ali), 200 ether);
    // excess remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 2 ether);

    hevm.warp(block.timestamp + 5 weeks);
    uint256 currentProtocolTokenSupply = protocolToken.totalSupply();
    GuyRecyclingSurplusAuction(bob).settleAuction(id);
    assertEq(protocolToken.totalSupply(), currentProtocolTokenSupply - 1 ether);

    // high bidder gets the amount sold
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    assertEq(safeEngine.coinBalance(bob), 100 ether);
    // income is transferred to address(0)
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 0 ether);
    assertEq(protocolToken.balanceOf(surplusAuctionHouse.params().bidReceiver), 1 ether);
  }

  function test_bid_increase() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertTrue(GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1.0 ether));
    assertTrue(!GuyRecyclingSurplusAuction(bob).try_increaseBidSize(id, 1.01 ether));
    // high bidder is subject to beg
    assertTrue(!GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1.01 ether));
    assertTrue(GuyRecyclingSurplusAuction(bob).try_increaseBidSize(id, 1.07 ether));
  }

  function test_restart_auction() public {
    // start an auction
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // check no tick
    assertTrue(!GuyRecyclingSurplusAuction(ali).try_restartAuction(id));
    // run past the end
    hevm.warp(block.timestamp + 2 weeks);
    // check not biddable
    assertTrue(!GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
    assertTrue(GuyRecyclingSurplusAuction(ali).try_restartAuction(id));
    // check biddable
    assertTrue(GuyRecyclingSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
  }

  function testFail_terminate_prematurely() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 1 ether);
    surplusAuctionHouse.terminateAuctionPrematurely(id);
  }

  function test_terminate_prematurely() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyRecyclingSurplusAuction(ali).increaseBidSize(id, 1 ether);
    // Shutdown
    surplusAuctionHouse.disableContract();
    surplusAuctionHouse.terminateAuctionPrematurely(id);
  }
}

contract SinglePostSettlementSurplusAuctionHouseTest is DSTest {
  Hevm hevm;

  PostSettlementSurplusAuctionHouse surplusAuctionHouse;
  SAFEEngine safeEngine;
  ProtocolToken protocolToken;

  address ali;
  address bob;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);
    protocolToken = new ProtocolToken('', '');

    IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _pssahParams = IPostSettlementSurplusAuctionHouse
      .PostSettlementSAHParams({bidIncrease: 1.05e18, bidDuration: 3 hours, totalAuctionLength: 2 days});
    surplusAuctionHouse =
      new PostSettlementSurplusAuctionHouse(address(safeEngine), address(protocolToken), _pssahParams);

    ali = address(new GuyPostSurplusAuction(surplusAuctionHouse));
    bob = address(new GuyPostSurplusAuction(surplusAuctionHouse));

    safeEngine.approveSAFEModification(address(surplusAuctionHouse));

    safeEngine.createUnbackedDebt(address(this), address(this), 1000 ether);

    protocolToken.mint(address(this), 1000 ether);

    protocolToken.transfer(ali, 200 ether);
    protocolToken.transfer(bob, 200 ether);
  }

  function test_start_auction() public {
    assertEq(safeEngine.coinBalance(address(this)), 1000 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 100 ether);
  }

  function test_increase_bid_same_bidder() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    GuyPostSurplusAuction(ali).increaseBidSize(id, 190 ether);
    assertEq(protocolToken.balanceOf(ali), 10 ether);
    GuyPostSurplusAuction(ali).increaseBidSize(id, 200 ether);
    assertEq(protocolToken.balanceOf(ali), 0);
  }

  function test_increaseBidSize() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // amount to buy taken from creator
    assertEq(safeEngine.coinBalance(address(this)), 900 ether);

    GuyPostSurplusAuction(ali).increaseBidSize(id, 1 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(ali), 199 ether);
    // payment remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 1 ether);

    GuyPostSurplusAuction(bob).increaseBidSize(id, 2 ether);
    // bid taken from bidder
    assertEq(protocolToken.balanceOf(bob), 198 ether);
    // prev bidder refunded
    assertEq(protocolToken.balanceOf(ali), 200 ether);
    // excess remains in auction
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 2 ether);

    hevm.warp(block.timestamp + 5 weeks);
    GuyPostSurplusAuction(bob).settleAuction(id);
    // high bidder gets the amount sold
    assertEq(safeEngine.coinBalance(address(surplusAuctionHouse)), 0 ether);
    assertEq(safeEngine.coinBalance(bob), 100 ether);
    // income is burned
    assertEq(protocolToken.balanceOf(address(surplusAuctionHouse)), 0 ether);
  }

  function test_bid_increase() public {
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    assertTrue(GuyPostSurplusAuction(ali).try_increaseBidSize(id, 1.0 ether));
    assertTrue(!GuyPostSurplusAuction(bob).try_increaseBidSize(id, 1.01 ether));
    // high bidder is subject to beg
    assertTrue(!GuyPostSurplusAuction(ali).try_increaseBidSize(id, 1.01 ether));
    assertTrue(GuyPostSurplusAuction(bob).try_increaseBidSize(id, 1.07 ether));
  }

  function test_restart_auction() public {
    // start an auction
    uint256 id = surplusAuctionHouse.startAuction({_amountToSell: 100 ether, _initialBid: 0});
    // check no tick
    assertTrue(!GuyPostSurplusAuction(ali).try_restartAuction(id));
    // run past the end
    hevm.warp(block.timestamp + 2 weeks);
    // check not biddable
    assertTrue(!GuyPostSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
    assertTrue(GuyPostSurplusAuction(ali).try_restartAuction(id));
    // check biddable
    assertTrue(GuyPostSurplusAuction(ali).try_increaseBidSize(id, 1 ether));
  }
}
