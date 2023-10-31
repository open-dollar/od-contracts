// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';

import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {
  ICollateralAuctionHouseFactory,
  CollateralAuctionHouseFactory
} from '@contracts/factories/CollateralAuctionHouseFactory.sol';
import {IOracleRelayer, OracleRelayerForTest} from '@test/mocks/OracleRelayerForTest.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

import {DelayedOracleForTest} from '@test/mocks/DelayedOracleForTest.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';

import {Math, WAD, RAY, RAD} from '@libraries/Math.sol';

contract Guy {
  ICollateralAuctionHouse collateralAuctionHouse;

  constructor(ICollateralAuctionHouse collateralAuctionHouse_) {
    collateralAuctionHouse = collateralAuctionHouse_;
  }

  function approveSAFEModification(address safe) public {
    address safeEngine = address(collateralAuctionHouse.safeEngine());
    SAFEEngine(safeEngine).approveSAFEModification(safe);
  }

  function buyCollateral(uint256 id, uint256 wad) public returns (uint256 bought, uint256 bidded) {
    return collateralAuctionHouse.buyCollateral(id, wad);
  }

  function try_buyCollateral(uint256 id, uint256 wad) public returns (bool ok) {
    string memory sig = 'buyCollateral(uint256,uint256)';
    (ok,) = address(collateralAuctionHouse).call(abi.encodeWithSignature(sig, id, wad));
  }

  function try_terminateAuctionPrematurely(uint256 id) public returns (bool ok) {
    string memory sig = 'terminateAuctionPrematurely(uint256)';
    (ok,) = address(collateralAuctionHouse).call(abi.encodeWithSignature(sig, id));
  }
}

contract DummyLiquidationEngine {
  uint256 public currentOnAuctionSystemCoins;

  constructor(uint256 rad) {
    currentOnAuctionSystemCoins = rad;
  }

  function removeCoinsFromAuction(uint256 rad) external {
    currentOnAuctionSystemCoins -= rad;
  }

  function addAuthorization(address) external {}
}

abstract contract SingleCollateralAuctionHouseTest is HaiTest {
  using Math for uint256;

  DummyLiquidationEngine liquidationEngine;
  SAFEEngine safeEngine;
  ICollateralAuctionHouse collateralAuctionHouse;
  OracleRelayerForTest oracleRelayer;
  DelayedOracleForTest collateralFSM;
  OracleForTest collateralMedian;
  OracleForTest systemCoinMedian;

  address ali;
  address bob;
  address auctionIncomeRecipient;
  address safeAuctioned = address(0xacab);

  // --- Virtual methods ---

  function _deployCollateralAuctionHouse(ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams)
    internal
    virtual
    returns (ICollateralAuctionHouse _collateralAuctionHouse);

  function _modifyParameters(bytes32 _param, bytes memory _data) internal virtual;
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal virtual;

  function setUp() public {
    vm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('collateralType', abi.encode(_safeEngineCollateralParams));

    liquidationEngine = new DummyLiquidationEngine(rad(1000 ether));

    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams = ICollateralAuctionHouse
      .CollateralAuctionHouseParams({
      minDiscount: 0.95e18, // 5% discount
      maxDiscount: 0.95e18, // 5% discount
      perSecondDiscountUpdateRate: RAY, // [ray]
      minimumBid: 1e18 // 1 system coin
    });

    systemCoinMedian = new OracleForTest(uint256(0));
    collateralMedian = new OracleForTest(uint256(0));
    collateralFSM = new DelayedOracleForTest(uint256(0), address(collateralMedian));

    // deploy oracle relayer
    IOracleRelayer.OracleRelayerParams memory _oracleRelayerParams =
      IOracleRelayer.OracleRelayerParams({redemptionRateUpperBound: RAY * WAD, redemptionRateLowerBound: 1});
    oracleRelayer =
      new OracleRelayerForTest(address(safeEngine), IBaseOracle(address(systemCoinMedian)), _oracleRelayerParams);
    oracleRelayer.setRedemptionPrice(5 * RAY);

    collateralAuctionHouse = _deployCollateralAuctionHouse(_cahParams);

    // initialize cType
    IOracleRelayer.OracleRelayerCollateralParams memory _oracleRelayerCParams = IOracleRelayer
      .OracleRelayerCollateralParams({
      oracle: IDelayedOracle(address(collateralFSM)),
      safetyCRatio: 1e27,
      liquidationCRatio: 1e27
    });
    oracleRelayer.initializeCollateralType('collateralType', abi.encode(_oracleRelayerCParams));

    // setup oracleRelayer
    _modifyParameters('oracleRelayer', abi.encode(oracleRelayer));

    ali = address(new Guy(collateralAuctionHouse));
    bob = address(new Guy(collateralAuctionHouse));
    auctionIncomeRecipient = newAddress();

    Guy(ali).approveSAFEModification(address(collateralAuctionHouse));
    Guy(bob).approveSAFEModification(address(collateralAuctionHouse));
    safeEngine.approveSAFEModification(address(collateralAuctionHouse));

    safeEngine.modifyCollateralBalance('collateralType', address(this), 1000 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 ether));
    safeEngine.createUnbackedDebt(address(0), bob, rad(200 ether));
  }

  // --- Math ---
  function rad(uint256 wad) internal pure returns (uint256 z) {
    z = wad * 10 ** 27;
  }

  // General tests
  function test_modifyParameters() public {
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.9e18));
    _modifyParameters('collateralType', 'minDiscount', abi.encode(0.91e18));
    _modifyParameters('collateralType', 'minimumBid', abi.encode(100 * WAD));
    _modifyParameters('collateralType', 'perSecondDiscountUpdateRate', abi.encode(RAY - 100));

    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _params = collateralAuctionHouse.params();

    assertEq(_params.minDiscount, 0.91e18);
    assertEq(_params.maxDiscount, 0.9e18);
    assertEq(_params.perSecondDiscountUpdateRate, RAY - 100);
    assertEq(_params.minimumBid, 100 * WAD);
  }

  function test_no_min_discount() public {
    _modifyParameters('collateralType', 'minDiscount', abi.encode(1 ether));
  }

  function testFail_max_discount_lower_than_min() public {
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(1 ether - 1));
  }

  function test_startAuction() public {
    collateralAuctionHouse.startAuction({
      _collateralToSell: 100 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
  }

  function testFail_buyCollateral_inexistent_auction() public {
    // can't buyCollateral on non-existent
    collateralAuctionHouse.buyCollateral(42, 5 * WAD);
  }

  function testFail_buyCollateral_null_auction() public {
    collateralAuctionHouse.startAuction({
      _collateralToSell: 100 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
    // can't buy collateral on non-existent
    collateralAuctionHouse.buyCollateral(1, 0);
  }

  // Tests with a setup that's similar to a fixed discount auction
  function test_buy_some_collateral() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    (uint256 collateralBoughtView, uint256 adjustedBidView) = collateralAuctionHouse.getCollateralBought(id, 25 * WAD);
    (uint256 collateralBought, uint256 adjustedBid) = Guy(ali).buyCollateral(id, 25 * WAD);
    assertEq(collateralBoughtView, collateralBought);
    assertEq(adjustedBidView, adjustedBid);

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(975 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);

    assertEq(_auction.amountToRaise, 25 * RAD);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), collateralAuctionHouse.params().minDiscount);
    assertEq(_auction.forgoneCollateralReceiver, address(safeAuctioned));
    assertEq(_auction.auctionIncomeRecipient, auctionIncomeRecipient);

    assertTrue(collateralBought > 0);
    assertEq(adjustedBid, 25 * WAD);
    assertEq(safeEngine.coinBalance(_auction.auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_buy_leftover_collateral() public {
    /**
     * 1. Start auction with 1 collateral ($200) to sell and 300 ($200 + extra100) system coins to raise
     * 2. Buy 0.90 collateral (if buying all it would settle the auction)
     * 3. Bid all to buy 0.1 collateral (should bid 20 coins, not 120)
     */
    collateralAuctionHouse.modifyParameters('minDiscount', abi.encode(WAD));
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(300 * RAD - 200 ether));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 300 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    (uint256 collateralBoughtView, uint256 adjustedBidView) = collateralAuctionHouse.getCollateralBought(id, 180 * WAD);
    (uint256 collateralBought, uint256 adjustedBid) = Guy(ali).buyCollateral(id, 180 * WAD);
    assertEq(collateralBought, collateralBoughtView);
    assertEq(adjustedBid, adjustedBidView);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(collateralBought, 0.9 ether);
    assertEq(adjustedBid, 180 * WAD);
    assertEq(_auction.amountToSell, 1 ether - collateralBought);
    assertEq(_auction.amountToRaise, 120 * RAD);

    // NOTE: this tx could try to be the 1st one, but get frontrunned and end up overbidding
    (uint256 newCollateralBoughtView, uint256 newAdjustedBidView) =
      collateralAuctionHouse.getCollateralBought(id, 120 * WAD);
    (uint256 newCollateralBought, uint256 newAdjustedBid) = Guy(ali).buyCollateral(id, 120 * WAD);
    assertEq(newCollateralBought, newCollateralBoughtView);
    assertEq(newAdjustedBid, newAdjustedBidView);

    _auction = collateralAuctionHouse.auctions(id);

    /**
     * - the new adjusted bid should be adjusted to the collateral left to sell
     * - in the example, there are 0.1 collateral left to sell (at $200)
     * - the adjusted bid should be 0.1 * 200 = 20 system coins
     * - the auction should be settled with 100 system coins left to raise
     */
    assertEq(newCollateralBought, 1 ether - collateralBought); // ok
    assertEq(newAdjustedBid, 20 * WAD); // capped to collateral amount
    assertEq(_auction.amountToSell, 0); // ok
    assertEq(_auction.amountToRaise, 0); // ok: settled auction gets deleted
  }

  function test_buy_all_collateral() public {
    oracleRelayer.setRedemptionPrice(2 * RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    uint256 _discountedCollateralPrice = (200 ether * RAY / oracleRelayer.redemptionPrice()) * 0.95e18 / WAD;

    assertEq(_discountedCollateralPrice, 95 ether);

    (uint256 collateralBoughtView, uint256 adjustedBidView) = collateralAuctionHouse.getCollateralBought(id, 50 * WAD);
    (uint256 collateralBought, uint256 adjustedBid) = Guy(ali).buyCollateral(id, 50 * WAD);
    assertEq(collateralBoughtView, collateralBought);
    assertEq(adjustedBidView, adjustedBid);

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(950 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), WAD); // no discount

    assertEq(collateralBought, 526_315_789_473_684_210);
    assertEq(adjustedBid, 50 * WAD);
    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 526_315_789_473_684_210
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 1 ether - 526_315_789_473_684_210);
  }

  function testFail_start_tiny_collateral_auction() public {
    oracleRelayer.setRedemptionPrice(2 * RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    collateralAuctionHouse.startAuction({
      _collateralToSell: 100,
      _amountToRaise: 50,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
  }

  function test_big_discount_buy() public {
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.1e18)); // 90% discount
    _modifyParameters('collateralType', 'minDiscount', abi.encode(0.1e18)); // 90% discount
    oracleRelayer.setRedemptionPrice(RAY); // $1
    collateralFSM.setPriceAndValidity(200 ether, true); // $200
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether, // $200 @(90% discount) => $20
      _amountToRaise: 50 * RAD, // $50
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    // tries to buy all collateral, but gets capped to collateral amount ($20)
    Guy(ali).buyCollateral(id, 50 * WAD);
    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 20 * RAD);

    // auction gets settled (deleted)
    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), WAD); // no discount

    // collateral auction house has no collateral tokens
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    // bidder has all initially offered collateral tokens
    assertEq(safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 1 ether);
    // safe receives no collateral tokens back
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  function test_small_discount_buy() public {
    oracleRelayer.setRedemptionPrice(RAY);
    _modifyParameters('collateralType', 'minDiscount', abi.encode(0.99e18));
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.99e18));
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
    Guy(ali).buyCollateral(id, 50 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), WAD); // no discount

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 252_525_252_525_252_525
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 1 ether - 252_525_252_525_252_525);
  }

  function test_consecutive_small_auctions() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    for (uint256 i = 0; i < 10; i++) {
      Guy(ali).buyCollateral(id, 5 * WAD);
    }

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(950 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), WAD); // no discount

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid,
      1 ether - 736_842_105_263_157_900
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 1 ether - 263_157_894_736_842_100);
  }

  function test_settle_auction() public {
    oracleRelayer.setRedemptionPrice(2 * RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    vm.warp(block.timestamp + 1);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(1000 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether);
    assertEq(_auction.amountToRaise, 50 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 0);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether);
    assertEq(safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 0);
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  function testFail_terminate_inexistent() public {
    collateralAuctionHouse.terminateAuctionPrematurely(1);
  }

  function test_terminateAuctionPrematurely() public {
    oracleRelayer.setRedemptionPrice(2 * RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(975 ether));
    collateralAuctionHouse.terminateAuctionPrematurely(1);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(950 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), WAD); // no discount

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(safeEngine.tokenCollateral('collateralType', address(this)), 999_736_842_105_263_157_895);
    assertEq(uint256(999_736_842_105_263_157_895).add(263_157_894_736_842_105), 1000 ether);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 263_157_894_736_842_105
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  // Custom tests for the increasing discount implementation
  function test_small_discount_change_rate_auction_right_away() public {
    _modifyParameters('collateralType', 'perSecondDiscountUpdateRate', abi.encode(999_998_607_628_240_588_157_433_861)); // -0.5% per hour
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.93e18));

    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 49 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(951 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 742_105_263_157_894_737);
    assertEq(_auction.amountToRaise, RAY * WAD);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), collateralAuctionHouse.params().minDiscount);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 49 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 742_105_263_157_894_737);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid,
      1 ether - 742_105_263_157_894_737
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  function test_small_discount_change_rate_auction_after_short_timeline() public {
    _modifyParameters('collateralType', 'perSecondDiscountUpdateRate', abi.encode(999_998_607_628_240_588_157_433_861)); // -0.5% per hour
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.93e18));

    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    vm.warp(block.timestamp + 30 minutes);
    Guy(ali).buyCollateral(id, 49 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(951 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 741_458_098_434_345_369);
    assertEq(_auction.amountToRaise, RAY * WAD);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), 947_622_023_804_850_158);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 49 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 741_458_098_434_345_369);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid,
      1 ether - 741_458_098_434_345_369
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  /**
   * NOTE: since rate timeline was deprecated, this test uses an approximate -7% per hour rate to simulate old conditions
   * rateTimeline was supposed to jump to maxDiscount in 1 hour, but since deprecated, we use a rate that simulates the behaviour
   */
  function test_small_discount_change_rate_bid_end_rate_timeline() public {
    _modifyParameters('collateralType', 'perSecondDiscountUpdateRate', abi.encode(999_979_841_677_394_287_735_580_746)); // -7% per hour
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.93e18));

    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    vm.warp(block.timestamp + 1 hours);
    Guy(ali).buyCollateral(id, 49 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(951 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 736_559_139_784_946_237);
    assertEq(_auction.amountToRaise, RAY * WAD);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), 930_000_000_000_000_000);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 49 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 736_559_139_784_946_237);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid,
      1 ether - 736_559_139_784_946_237
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  function test_small_discount_change_rate_auction_long_after_long_timeline() public {
    _modifyParameters('collateralType', 'perSecondDiscountUpdateRate', abi.encode(999_998_607_628_240_588_157_433_861)); // -0.5% per hour
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.93e18));

    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    vm.warp(block.timestamp + 3650 days);
    Guy(ali).buyCollateral(id, 49 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(951 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 736_559_139_784_946_237);
    assertEq(_auction.amountToRaise, RAY * WAD);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), 930_000_000_000_000_000);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 49 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 736_559_139_784_946_237);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid,
      1 ether - 736_559_139_784_946_237
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  function test_auction_multi_times_at_different_timestamps() public {
    _modifyParameters('collateralType', 'perSecondDiscountUpdateRate', abi.encode(999_998_607_628_240_588_157_433_861)); // -0.5% per hour
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.93e18));

    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.setPriceAndValidity(200 ether, true);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _collateralToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    for (uint256 i = 0; i < 10; i++) {
      vm.warp(block.timestamp + 1 minutes);
      Guy(ali).buyCollateral(id, 5 * WAD);
    }

    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(950 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);

    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);
    assertEq(collateralAuctionHouse.getAuctionDiscount(id), WAD); // no discount

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid,
      1 ether - 736_721_153_320_545_015
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 736_721_153_320_545_015);
  }
}

contract FactorySingleCollateralAuctionHouseTest is SingleCollateralAuctionHouseTest {
  ICollateralAuctionHouseFactory factory;

  function _deployCollateralAuctionHouse(ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams)
    internal
    override
    returns (ICollateralAuctionHouse _collateralAuctionHouse)
  {
    factory = new CollateralAuctionHouseFactory(address(safeEngine), address(liquidationEngine), address(oracleRelayer));
    factory.initializeCollateralType('collateralType', abi.encode(_cahParams));

    return ICollateralAuctionHouse(ICollateralAuctionHouse(factory.collateralAuctionHouses('collateralType')));
  }

  function _modifyParameters(bytes32 _parameter, bytes memory _data) internal override {
    factory.modifyParameters(_parameter, _data);
  }

  function _modifyParameters(bytes32 _cType, bytes32 _parameter, bytes memory _data) internal override {
    factory.modifyParameters(_cType, _parameter, _data);
  }
}

contract OrphanSingleCollateralAuctionHouseTest is SingleCollateralAuctionHouseTest {
  function _deployCollateralAuctionHouse(ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams)
    internal
    override
    returns (ICollateralAuctionHouse _collateralAuctionHouse)
  {
    return
    new CollateralAuctionHouse(address(safeEngine), address(liquidationEngine), address(oracleRelayer), 'collateralType',
         _cahParams);
  }

  function _modifyParameters(bytes32 _parameter, bytes memory _data) internal override {
    collateralAuctionHouse.modifyParameters(_parameter, _data);
  }

  function _modifyParameters(bytes32, bytes32 _parameter, bytes memory _data) internal override {
    collateralAuctionHouse.modifyParameters(_parameter, _data);
  }
}
