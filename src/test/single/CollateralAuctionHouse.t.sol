// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@test/utils/HaiTest.t.sol';

import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {CollateralAuctionHouse, ICollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {CollateralAuctionHouseFactory} from '@contracts/factories/CollateralAuctionHouseFactory.sol';
import {IOracleRelayer, OracleRelayerForTest} from '@contracts/for-test/OracleRelayerForTest.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

import {Math, WAD, RAY, RAD} from '@libraries/Math.sol';

contract Guy {
  CollateralAuctionHouse collateralAuctionHouse;

  constructor(CollateralAuctionHouse collateralAuctionHouse_) {
    collateralAuctionHouse = collateralAuctionHouse_;
  }

  function approveSAFEModification(address safe) public {
    address safeEngine = address(collateralAuctionHouse.safeEngine());
    SAFEEngine(safeEngine).approveSAFEModification(safe);
  }

  function buyCollateral(uint256 id, uint256 wad) public {
    collateralAuctionHouse.buyCollateral(id, wad);
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

contract Gal {}

contract RevertableMedian {
  function getResultWithValidity() external pure returns (bytes32, bool) {
    revert();
  }
}

contract Feed {
  address public priceSource;
  uint256 public priceFeedValue;
  bool public hasValidValue;

  constructor(bytes32 initPrice, bool initHas) {
    priceFeedValue = uint256(initPrice);
    hasValidValue = initHas;
  }

  function set_val(uint256 newPrice) external {
    priceFeedValue = newPrice;
  }

  function set_price_source(address priceSource_) external {
    priceSource = priceSource_;
  }

  function set_has(bool newHas) external {
    hasValidValue = newHas;
  }

  function getResultWithValidity() external view returns (uint256, bool) {
    return (priceFeedValue, hasValidValue);
  }
}

contract PartiallyImplementedFeed {
  uint256 public priceFeedValue;
  bool public hasValidValue;

  constructor(bytes32 initPrice, bool initHas) {
    priceFeedValue = uint256(initPrice);
    hasValidValue = initHas;
  }

  function set_val(uint256 newPrice) external {
    priceFeedValue = newPrice;
  }

  function set_has(bool newHas) external {
    hasValidValue = newHas;
  }

  function getResultWithValidity() external view returns (uint256, bool) {
    return (priceFeedValue, hasValidValue);
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
  CollateralAuctionHouse collateralAuctionHouse;
  OracleRelayerForTest oracleRelayer;
  Feed collateralFSM;
  Feed collateralMedian;
  Feed systemCoinMedian;

  address ali;
  address bob;
  address auctionIncomeRecipient;
  address safeAuctioned = address(0xacab);

  // --- Virtual methods ---

  function _deployCollateralAuctionHouse(
    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams,
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams
  ) internal virtual returns (CollateralAuctionHouse _collateralAuctionHouse);

  function _modifyParameters(bytes32 _param, bytes memory _data) internal virtual;
  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal virtual;

  function setUp() public {
    vm.warp(604_411_200);

    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: 0});
    safeEngine = new SAFEEngine(_safeEngineParams);

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: 0, debtFloor: 0});
    safeEngine.initializeCollateralType('collateralType', _safeEngineCollateralParams);

    liquidationEngine = new DummyLiquidationEngine(rad(1000 ether));

    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams = ICollateralAuctionHouse
      .CollateralAuctionHouseSystemCoinParams({
      lowerSystemCoinDeviation: WAD, // 0% deviation
      upperSystemCoinDeviation: WAD, // 0% deviation
      minSystemCoinDeviation: 0.999e18 // 0.1% deviation
    });

    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams = ICollateralAuctionHouse
      .CollateralAuctionHouseParams({
      minDiscount: 0.95e18, // 5% discount
      maxDiscount: 0.95e18, // 5% discount
      perSecondDiscountUpdateRate: RAY, // [ray]
      lowerCollateralDeviation: 0.9e18, // 10% deviation
      upperCollateralDeviation: 0.95e18, // 5% deviation
      minimumBid: 1e18 // 1 system coin
    });

    systemCoinMedian = new Feed(bytes32(uint256(0)), true);
    collateralMedian = new Feed(bytes32(uint256(0)), true);
    collateralFSM = new Feed(bytes32(uint256(0)), true);

    collateralFSM.set_price_source(address(collateralMedian));

    // deploy oracle relayer
    IOracleRelayer.OracleRelayerParams memory _oracleRelayerParams =
      IOracleRelayer.OracleRelayerParams({redemptionRateUpperBound: RAY * WAD, redemptionRateLowerBound: 1});
    oracleRelayer =
      new OracleRelayerForTest(address(safeEngine), IBaseOracle(address(systemCoinMedian)), _oracleRelayerParams);
    oracleRelayer.setRedemptionPrice(5 * RAY);

    collateralAuctionHouse = _deployCollateralAuctionHouse(_cahParams, _cahCParams);

    // initialize cType
    IOracleRelayer.OracleRelayerCollateralParams memory _oracleRelayerCParams = IOracleRelayer
      .OracleRelayerCollateralParams({
      oracle: IDelayedOracle(address(collateralFSM)),
      safetyCRatio: 1e27,
      liquidationCRatio: 1e27
    });
    oracleRelayer.initializeCollateralType('collateralType', _oracleRelayerCParams);

    // setup oracleRelayer
    _modifyParameters('oracleRelayer', abi.encode(oracleRelayer));

    ali = address(new Guy(collateralAuctionHouse));
    bob = address(new Guy(collateralAuctionHouse));
    auctionIncomeRecipient = address(new Gal());

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
    _modifyParameters('collateralType', 'lowerCollateralDeviation', abi.encode(0.95e18));
    _modifyParameters('collateralType', 'upperCollateralDeviation', abi.encode(0.9e18));
    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));
    _modifyParameters('minSystemCoinDeviation', abi.encode(0.99e18));

    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cParams = collateralAuctionHouse.cParams();
    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _params = collateralAuctionHouse.params();

    assertEq(_cParams.minDiscount, 0.91e18);
    assertEq(_cParams.maxDiscount, 0.9e18);
    assertEq(_cParams.lowerCollateralDeviation, 0.95e18);
    assertEq(_cParams.upperCollateralDeviation, 0.9e18);
    assertEq(_cParams.perSecondDiscountUpdateRate, RAY - 100);
    assertEq(_cParams.minimumBid, 100 * WAD);
    assertEq(_params.lowerSystemCoinDeviation, 0.95e18);
    assertEq(_params.upperSystemCoinDeviation, 0.9e18);
    assertEq(_params.minSystemCoinDeviation, 0.99e18);
  }

  function testFail_set_partially_implemented_collateralFSM() public {
    PartiallyImplementedFeed partiallyImplementedCollateralFSM = new PartiallyImplementedFeed(bytes32(uint256(0)), true);
    oracleRelayer.modifyParameters('collateralType', 'oracle', abi.encode(partiallyImplementedCollateralFSM));
  }

  function test_no_min_discount() public {
    _modifyParameters('collateralType', 'minDiscount', abi.encode(1 ether));
  }

  function testFail_max_discount_lower_than_min() public {
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(1 ether - 1));
  }

  function test_getSystemCoinFloorDeviatedPrice() public {
    _modifyParameters('minSystemCoinDeviation', abi.encode(0.9e18));

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(1e18));
    assertEq(
      collateralAuctionHouse.getSystemCoinFloorDeviatedPrice(oracleRelayer.redemptionPrice()),
      oracleRelayer.redemptionPrice()
    );

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    assertEq(
      collateralAuctionHouse.getSystemCoinFloorDeviatedPrice(oracleRelayer.redemptionPrice()),
      oracleRelayer.redemptionPrice()
    );

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.9e18));
    assertEq(collateralAuctionHouse.getSystemCoinFloorDeviatedPrice(oracleRelayer.redemptionPrice()), 4.5e27);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.89e18));
    assertEq(collateralAuctionHouse.getSystemCoinFloorDeviatedPrice(oracleRelayer.redemptionPrice()), 4.45e27);
  }

  function test_getSystemCoinCeilingDeviatedPrice() public {
    _modifyParameters('minSystemCoinDeviation', abi.encode(0.9e18));

    _modifyParameters('upperSystemCoinDeviation', abi.encode(1e18));
    assertEq(
      collateralAuctionHouse.getSystemCoinCeilingDeviatedPrice(oracleRelayer.redemptionPrice()),
      oracleRelayer.redemptionPrice()
    );

    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.95e18));
    assertEq(
      collateralAuctionHouse.getSystemCoinCeilingDeviatedPrice(oracleRelayer.redemptionPrice()),
      oracleRelayer.redemptionPrice()
    );

    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));
    assertEq(collateralAuctionHouse.getSystemCoinCeilingDeviatedPrice(oracleRelayer.redemptionPrice()), 5.5e27);

    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.89e18));
    assertEq(collateralAuctionHouse.getSystemCoinCeilingDeviatedPrice(oracleRelayer.redemptionPrice()), 5.55e27);
  }

  function test_startAuction() public {
    collateralAuctionHouse.startAuction({
      _amountToSell: 100 ether,
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
      _amountToSell: 100 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
    // can't buy collateral on non-existent
    collateralAuctionHouse.buyCollateral(1, 0);
  }

  function testFail_faulty_collateral_fsm_price() public {
    Feed faultyFeed = new Feed(bytes32(uint256(1)), false);
    oracleRelayer.modifyParameters('collateralType', 'oracle', abi.encode(faultyFeed));

    collateralAuctionHouse.startAuction({
      _amountToSell: 100 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
    collateralAuctionHouse.buyCollateral(1, 5 * WAD);
  }

  // Tests with a setup that's similar to a fixed discount auction
  function test_buy_some_collateral() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    (bool canBidThisAmount, uint256 adjustedBid) = collateralAuctionHouse.getAdjustedBid(id, 25 * WAD);
    Guy(ali).buyCollateral(id, 25 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(975 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);

    assertEq(_auction.amountToRaise, 25 * RAD);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(_auction.currentDiscount, collateralAuctionHouse.cParams().minDiscount);
    assertEq(_auction.maxDiscount, collateralAuctionHouse.cParams().maxDiscount);
    assertEq(_auction.perSecondDiscountUpdateRate, collateralAuctionHouse.cParams().perSecondDiscountUpdateRate);
    assertEq(_auction.latestDiscountUpdateTime, block.timestamp);
    assertEq(_auction.forgoneCollateralReceiver, address(safeAuctioned));
    assertEq(_auction.auctionIncomeRecipient, auctionIncomeRecipient);

    assertTrue(canBidThisAmount);
    assertEq(adjustedBid, 25 * WAD);
    assertEq(safeEngine.coinBalance(_auction.auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_buy_all_collateral() public {
    oracleRelayer.setRedemptionPrice(2 * RAY);
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    assertEq(
      collateralAuctionHouse.getDiscountedCollateralPrice(200 ether, 0, oracleRelayer.redemptionPrice(), 0.95e18),
      95 ether
    );

    (uint256 collateralBought, uint256 collateralBoughtAdjustedBid) =
      collateralAuctionHouse.getCollateralBought(id, 50 * WAD);

    assertEq(collateralBought, 526_315_789_473_684_210);
    assertEq(collateralBoughtAdjustedBid, 50 * WAD);

    (bool canBidThisAmount, uint256 adjustedBid) = collateralAuctionHouse.getAdjustedBid(id, 50 * WAD);
    Guy(ali).buyCollateral(id, 50 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(950 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);

    assertTrue(canBidThisAmount);
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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    collateralAuctionHouse.startAuction({
      _amountToSell: 100,
      _amountToRaise: 50,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
  }

  function test_buyCollateral_small_market_price() public {
    collateralFSM.set_val(0.01 ether);
    oracleRelayer.setRedemptionPrice(2 * RAY);
    (uint256 colMedianPrice, bool colMedianValidity) = collateralMedian.getResultWithValidity();
    assertEq(colMedianPrice, 0);
    assertTrue(colMedianValidity);

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    (bool canBidThisAmount, uint256 adjustedBid) = collateralAuctionHouse.getAdjustedBid(id, 5 * WAD);
    Guy(ali).buyCollateral(id, 5 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(950 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);

    assertTrue(canBidThisAmount);
    assertEq(adjustedBid, 5 * WAD);
    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 5 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 1 ether);
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  function test_big_discount_buy() public {
    oracleRelayer.setRedemptionPrice(RAY);
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.1e18));
    _modifyParameters('collateralType', 'minDiscount', abi.encode(0.1e18));
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
    Guy(ali).buyCollateral(id, 50 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 1_000_000_000_000_000_000
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 0);
  }

  function test_small_discount_buy() public {
    oracleRelayer.setRedemptionPrice(RAY);
    _modifyParameters('collateralType', 'minDiscount', abi.encode(0.99e18));
    _modifyParameters('collateralType', 'maxDiscount', abi.encode(0.99e18));
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });
    Guy(ali).buyCollateral(id, 50 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 252_525_252_525_252_525
    );
    assertEq(safeEngine.tokenCollateral('collateralType', address(safeAuctioned)), 1 ether - 252_525_252_525_252_525);
  }

  function test_collateral_median_and_collateral_fsm_equal() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_collateral_median_higher_than_collateral_fsm_floor() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(181 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 145_391_102_064_553_649);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 145_391_102_064_553_649
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 145_391_102_064_553_649
    );
  }

  function test_collateral_median_lower_than_collateral_fsm_ceiling() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(209 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 125_912_868_295_139_763);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 125_912_868_295_139_763
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 125_912_868_295_139_763
    );
  }

  function test_collateral_median_higher_than_collateral_fsm_ceiling() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(500 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 125_313_283_208_020_050);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 125_313_283_208_020_050
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 125_313_283_208_020_050
    );
  }

  function test_collateral_median_lower_than_collateral_fsm_floor() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(1 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 146_198_830_409_356_725);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 146_198_830_409_356_725
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 146_198_830_409_356_725
    );
  }

  function test_collateral_median_lower_than_collateral_fsm_buy_all() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(1 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 50 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 292_397_660_818_713_450
    );
  }

  function test_collateral_median_reverts() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    RevertableMedian revertMedian = new RevertableMedian();
    collateralFSM.set_price_source(address(revertMedian));
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_system_coin_median_and_redemption_equal() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(1 ether);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_system_coin_median_higher_than_redemption_floor() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(0.975e18);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 128_289_473_684_210_526);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 128_289_473_684_210_526
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 128_289_473_684_210_526
    );
  }

  function test_system_coin_median_lower_than_redemption_ceiling() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(1.05e18);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 138_157_894_736_842_105);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 138_157_894_736_842_105
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 138_157_894_736_842_105
    );
  }

  function test_system_coin_median_higher_than_redemption_ceiling() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(1.15e18);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 144_736_842_105_263_157);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 144_736_842_105_263_157
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 144_736_842_105_263_157
    );
  }

  function test_system_coin_median_lower_than_redemption_floor() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(0.9e18);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 125_000_000_000_000_000);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 125_000_000_000_000_000
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 125_000_000_000_000_000
    );
  }

  function test_system_coin_median_lower_than_redemption_buy_all() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(0.9e18);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 50 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 0);
    assertEq(_auction.amountToRaise, 0);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
    assertEq(safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 0);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 250_000_000_000_000_000
    );
  }

  function test_system_coin_median_reverts() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    RevertableMedian revertMedian = new RevertableMedian();

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(revertMedian));
    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_system_coin_lower_collateral_median_higher() public {
    oracleRelayer.setRedemptionPrice(RAY);
    systemCoinMedian.set_val(0.9e18);

    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(220 ether);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 119_047_619_047_619_047);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 119_047_619_047_619_047
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 119_047_619_047_619_047
    );
  }

  function test_system_coin_higher_collateral_median_lower() public {
    oracleRelayer.setRedemptionPrice(RAY);
    systemCoinMedian.set_val(1.1e18);

    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(180 ether);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 160_818_713_450_292_397);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 160_818_713_450_292_397
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 160_818_713_450_292_397
    );
  }

  function test_system_coin_lower_collateral_median_lower() public {
    oracleRelayer.setRedemptionPrice(RAY);
    systemCoinMedian.set_val(0.9e18);

    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(180 ether);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 138_888_888_888_888_888);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 138_888_888_888_888_888
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 138_888_888_888_888_888
    );
  }

  function test_system_coin_higher_collateral_median_higher() public {
    oracleRelayer.setRedemptionPrice(RAY);
    systemCoinMedian.set_val(1.1e18);

    collateralFSM.set_val(200 ether);
    collateralMedian.set_val(210 ether);

    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 137_844_611_528_822_055);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 137_844_611_528_822_055
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 137_844_611_528_822_055
    );
  }

  function test_min_system_coin_deviation_exceeds_lower_deviation() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(0.95e18);

    _modifyParameters('minSystemCoinDeviation', abi.encode(0.94e18));
    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_min_system_coin_deviation_exceeds_higher_deviation() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    systemCoinMedian.set_val(1.05e18);

    _modifyParameters('minSystemCoinDeviation', abi.encode(0.89e18));
    _modifyParameters('lowerSystemCoinDeviation', abi.encode(0.95e18));
    _modifyParameters('upperSystemCoinDeviation', abi.encode(0.9e18));

    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 25 * WAD);

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 1 ether - 131_578_947_368_421_052);
    assertEq(_auction.amountToRaise, 25 * RAD);

    assertEq(safeEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(collateralAuctionHouse)), 1 ether - 131_578_947_368_421_052
    );
    assertEq(
      safeEngine.tokenCollateral('collateralType', address(ali)) - collateralAmountPreBid, 131_578_947_368_421_052
    );
  }

  function test_consecutive_small_auctions() public {
    oracleRelayer.setRedemptionPrice(RAY);
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    vm.warp(block.timestamp + 1);
    collateralAuctionHouse.settleAuction(id);
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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
      _amountToRaise: 50 * RAD,
      _forgoneCollateralReceiver: safeAuctioned,
      _auctionIncomeRecipient: auctionIncomeRecipient
    });

    Guy(ali).buyCollateral(id, 49 * WAD);
    assertEq(liquidationEngine.currentOnAuctionSystemCoins(), rad(951 ether));

    ICollateralAuctionHouse.Auction memory _auction = collateralAuctionHouse.auctions(id);
    assertEq(_auction.amountToSell, 742_105_263_157_894_737);
    assertEq(_auction.amountToRaise, RAY * WAD);
    assertEq(_auction.currentDiscount, collateralAuctionHouse.cParams().minDiscount);
    assertEq(_auction.perSecondDiscountUpdateRate, 999_998_607_628_240_588_157_433_861);
    assertEq(_auction.latestDiscountUpdateTime, block.timestamp);

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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
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
    assertEq(_auction.currentDiscount, 947_622_023_804_850_158);
    assertEq(_auction.perSecondDiscountUpdateRate, 999_998_607_628_240_588_157_433_861);
    assertEq(_auction.latestDiscountUpdateTime, block.timestamp);

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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
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
    assertEq(_auction.currentDiscount, 930_000_000_000_000_000);
    assertEq(_auction.perSecondDiscountUpdateRate, 999_979_841_677_394_287_735_580_746);
    assertEq(_auction.latestDiscountUpdateTime, block.timestamp);

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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
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
    assertEq(_auction.currentDiscount, 930_000_000_000_000_000);
    assertEq(_auction.perSecondDiscountUpdateRate, 999_998_607_628_240_588_157_433_861);
    assertEq(_auction.latestDiscountUpdateTime, block.timestamp);

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
    collateralFSM.set_val(200 ether);
    safeEngine.createUnbackedDebt(address(0), ali, rad(200 * RAD - 200 ether));

    uint256 collateralAmountPreBid = safeEngine.tokenCollateral('collateralType', address(ali));

    uint256 id = collateralAuctionHouse.startAuction({
      _amountToSell: 1 ether,
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
    assertEq(_auction.currentDiscount, 0);
    assertEq(_auction.perSecondDiscountUpdateRate, 0);
    assertEq(_auction.latestDiscountUpdateTime, 0);

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
  CollateralAuctionHouseFactory factory;

  function _deployCollateralAuctionHouse(
    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams,
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams
  ) internal override returns (CollateralAuctionHouse _collateralAuctionHouse) {
    factory =
    new CollateralAuctionHouseFactory(address(safeEngine), address(oracleRelayer), address(liquidationEngine), _cahParams);

    return CollateralAuctionHouse(factory.deployCollateralAuctionHouse('collateralType', _cahCParams));
  }

  function _modifyParameters(bytes32 _parameter, bytes memory _data) internal override {
    factory.modifyParameters(_parameter, _data);
  }

  function _modifyParameters(bytes32 _cType, bytes32 _parameter, bytes memory _data) internal override {
    factory.modifyParameters(_cType, _parameter, _data);
  }
}

contract OrphanSingleCollateralAuctionHouseTest is SingleCollateralAuctionHouseTest {
  function _deployCollateralAuctionHouse(
    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams,
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams
  ) internal override returns (CollateralAuctionHouse _collateralAuctionHouse) {
    return
    new CollateralAuctionHouse(address(safeEngine), address(oracleRelayer), address(liquidationEngine), 'collateralType',
         _cahParams,
         _cahCParams);
  }

  function _modifyParameters(bytes32 _parameter, bytes memory _data) internal override {
    collateralAuctionHouse.modifyParameters(_parameter, _data);
  }

  function _modifyParameters(bytes32 _cType, bytes32 _parameter, bytes memory _data) internal override {
    collateralAuctionHouse.modifyParameters(_cType, _parameter, _data);
  }
}
