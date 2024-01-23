// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Common, COLLAT, DEBT, TEST_ETH_PRICE_DROP} from './Common.t.sol';
import {Math} from '@libraries/Math.sol';
import {OracleForTest} from '@testnet/mocks/OracleForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {WSTETH, ETH_A, OD_INITIAL_PRICE} from '@script/Params.s.sol';
import {WAD, RAY, YEAR} from '@libraries/Math.sol';

import {BaseUser} from '@testnet/scopes/BaseUser.t.sol';
import {DirectUser} from '@testnet/scopes/DirectUser.t.sol';
import {ProxyUser} from '@testnet/scopes/ProxyUser.t.sol';

abstract contract E2EGlobalSettlementTest is BaseUser, Common {
  using Math for uint256;

  uint256 LIQUIDATION_QUANTITY = 1000e45;
  uint256 COLLATERAL_PRICE = 100e18;
  uint256 COLLATERAL_B_DROP = 75e18;
  uint256 COLLATERAL_C_DROP = 5e18;
  uint256 LIQUIDATION_RATIO = 1.5e27;
  uint256 ALICE_DEBT = 20e18;
  uint256 BOB_DEBT = 50e18;
  uint256 CAROL_DEBT = 60e18;

  function test_global_settlement_multicollateral() public {
    _multiCollateralSetup();

    assertEq(oracleRelayer.redemptionPrice(), OD_INITIAL_PRICE * 1e9);

    // NOTE: all collaterals have COLLATERAL_PRICE
    // alice has a 20% LTV
    (uint256 _aliceGeneratedDebt, uint256 _aliceLockedCollateral) = _getSafeStatus('TKN-A', alice);
    assertEq(_aliceGeneratedDebt.rdiv(_aliceLockedCollateral * COLLATERAL_PRICE), 0.2e9);

    // bob has a 50% LTV
    (uint256 _bobGeneratedDebt, uint256 _bobLockedCollateral) = _getSafeStatus('TKN-A', bob);
    assertEq(_bobGeneratedDebt.rdiv(_bobLockedCollateral * COLLATERAL_PRICE), 0.5e9);

    // carol has a 60% LTV
    (uint256 _carolGeneratedDebt, uint256 _carolLockedCollateral) = _getSafeStatus('TKN-A', carol);
    assertEq(_carolGeneratedDebt.rdiv(_carolLockedCollateral * COLLATERAL_PRICE), 0.6e9);

    // NOTE: now B and C collaterals have less value
    _setCollateralPrice('TKN-B', COLLATERAL_B_DROP);
    _setCollateralPrice('TKN-C', COLLATERAL_C_DROP);

    vm.prank(deployer);
    globalSettlement.shutdownSystem();

    uint256 _totalAToRedeem;
    uint256 _totalBToRedeem;
    uint256 _totalCToRedeem;

    /* COLLATERAL TKN-A (maintained price) */
    globalSettlement.freezeCollateralType('TKN-A');

    {
      // alice can take 80% of TKN-A collateral
      uint256 _aliceARemainder = _freeCollateral(alice, 'TKN-A');
      assertEq(_aliceARemainder, 0.8e18);

      // bob can take 50% of TKN-A collateral
      uint256 _bobARemainder = _freeCollateral(bob, 'TKN-A');
      assertEq(_bobARemainder, 0.5e18);

      // carol can take 40% of TKN-A collateral
      uint256 _carolARemainder = _freeCollateral(carol, 'TKN-A');
      assertEq(_carolARemainder, 0.4e18);

      _totalAToRedeem = 3 * COLLAT - (_aliceARemainder + _bobARemainder + _carolARemainder);
    }

    /* COLLATERAL TKN-B (price dropped 25%) */
    globalSettlement.freezeCollateralType('TKN-B');

    {
      /**
       * alice debt = 20 OD
       * alice collateral = 1 TKN-B = 75 OD
       * alice pays debt with (20/75) = 0.266 TKN-B
       * alice has 0.733 TKN-B left
       * alice can take 73% of TKN-B collateral
       */
      uint256 _aliceBRemainder = _freeCollateral(alice, 'TKN-B');
      assertApproxEqAbs(_aliceBRemainder, 0.733e18, 0.001e18);

      // bob can take 33% of TKN-B collateral
      uint256 _bobBRemainder = _freeCollateral(bob, 'TKN-B');
      assertApproxEqAbs(_bobBRemainder, 0.333e18, 0.001e18);

      // carol can take 20% of TKN-B collateral
      uint256 _carolBRemainder = _freeCollateral(carol, 'TKN-B');
      assertApproxEqAbs(_carolBRemainder, 0.2e18, 0.001e18);

      _totalBToRedeem = 3 * COLLAT - (_aliceBRemainder + _bobBRemainder + _carolBRemainder);
    }

    /* COLLATERAL TKN-C (price dropped 95%) */
    globalSettlement.freezeCollateralType('TKN-C');

    /**
     * alice debt = 20 OD
     * alice collateral = 1 TKN-C = 5 OD
     * alice must pay debt with (20/5) = 4 TKN-C
     * alice is short 3 TKN-C
     */
    uint256 _aliceCRemainder = _freeCollateral(alice, 'TKN-C');
    assertEq(_aliceCRemainder, 0);
    assertApproxEqAbs(globalSettlement.collateralShortfall('TKN-C'), 3e18, 0.001e18);

    /**
     * bob debt = 50 OD
     * bob collateral = 1 TKN-C = 5 OD
     * bob must pay debt with (50/5) = 10 TKN-C
     * bob is short 9 TKN-C
     */
    uint256 _bobCRemainder = _freeCollateral(bob, 'TKN-C');
    assertEq(_bobCRemainder, 0);
    assertApproxEqAbs(globalSettlement.collateralShortfall('TKN-C'), 3e18 + 9e18, 0.001e18);

    /**
     * carol debt = 60 OD
     * carol collateral = 1 TKN-C = 5 OD
     * carol must pay debt with (60/5) = 12 TKN-C
     * carol is short 11 TKN-C
     */
    uint256 _carolCRemainder = _freeCollateral(carol, 'TKN-C');
    assertEq(_carolCRemainder, 0);
    assertApproxEqAbs(globalSettlement.collateralShortfall('TKN-C'), 3e18 + 9e18 + 11e18, 0.001e18);

    {
      /**
       * alice debt = 20 OD
       * alice collateral = 1 TKN-C = 5 OD
       * alice must pay debt with (20/5) = 4 TKN-C
       * alice has 0 TKN-C left
       * bob has 0 TKN-C left (higher debt)
       * carol has 0 TKN-C left (even higher debt)
       */
      _totalCToRedeem = 3 * COLLAT - (_aliceCRemainder + _bobCRemainder + _carolCRemainder);
    }

    /* SETTLEMENT */
    vm.warp(block.timestamp + globalSettlement.params().shutdownCooldown);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('TKN-A');
    globalSettlement.calculateCashPrice('TKN-B');
    globalSettlement.calculateCashPrice('TKN-C');

    // alice bob and carol redeem their OD
    uint256 _aliceCoins = ALICE_DEBT + ALICE_DEBT + ALICE_DEBT;
    uint256 _bobCoins = BOB_DEBT + BOB_DEBT + BOB_DEBT;
    uint256 _carolCoins = CAROL_DEBT + CAROL_DEBT + CAROL_DEBT;
    uint256 _totalCoins = _aliceCoins + _bobCoins + _carolCoins;

    _prepareCoinsForRedeeming(alice, _aliceCoins);
    _prepareCoinsForRedeeming(bob, _bobCoins);
    _prepareCoinsForRedeeming(carol, _carolCoins);

    {
      uint256 _aliceRedeemedCollateral = _redeemCollateral(alice, 'TKN-A', _aliceCoins);
      uint256 _bobRedeemedCollateral = _redeemCollateral(bob, 'TKN-A', _bobCoins);
      uint256 _carolRedeemedCollateral = _redeemCollateral(carol, 'TKN-A', _carolCoins);

      // All A debt was payed with collateral
      assertEq(globalSettlement.collateralShortfall('TKN-A'), 0);
      uint256 _collateralACashPrice = globalSettlement.collateralCashPrice('TKN-A');
      uint256 _totalADebt = ALICE_DEBT + BOB_DEBT + CAROL_DEBT;

      uint256 _collatAPrice = RAY.rdiv(COLLATERAL_PRICE * 1e9);
      assertEq(globalSettlement.finalCoinPerCollateralPrice('TKN-A'), _collatAPrice);
      assertApproxEqAbs(
        _collateralACashPrice, (_totalADebt * 1e9).rmul(_collatAPrice).rdiv(_totalCoins * 1e9), 0.001e18
      );

      assertApproxEqAbs(_aliceRedeemedCollateral, uint256(_aliceCoins).rmul(_collateralACashPrice), 0.001e18);
      assertApproxEqAbs(_bobRedeemedCollateral, uint256(_bobCoins).rmul(_collateralACashPrice), 0.001e18);
      assertApproxEqAbs(_carolRedeemedCollateral, uint256(_carolCoins).rmul(_collateralACashPrice), 0.001e18);

      // NOTE: contract may have some dust left
      assertApproxEqAbs(
        _getCollateralBalance(alice, 'TKN-A') + _getCollateralBalance(bob, 'TKN-A')
          + _getCollateralBalance(carol, 'TKN-A'),
        3 * COLLAT,
        0.001e18
      );
    }

    {
      uint256 _aliceRedeemedCollateral = _redeemCollateral(alice, 'TKN-B', _aliceCoins);
      uint256 _bobRedeemedCollateral = _redeemCollateral(bob, 'TKN-B', _bobCoins);
      uint256 _carolRedeemedCollateral = _redeemCollateral(carol, 'TKN-B', _carolCoins);

      // All B debt was payed with collateral
      assertEq(globalSettlement.collateralShortfall('TKN-B'), 0);
      uint256 _collateralBCashPrice = globalSettlement.collateralCashPrice('TKN-B');
      uint256 _totalBDebt = ALICE_DEBT + BOB_DEBT + CAROL_DEBT;

      uint256 _collatBPrice = RAY.rdiv(COLLATERAL_B_DROP * 1e9);
      assertEq(globalSettlement.finalCoinPerCollateralPrice('TKN-B'), _collatBPrice);
      assertApproxEqAbs(
        _collateralBCashPrice, (_totalBDebt * 1e9).rmul(_collatBPrice).rdiv(_totalCoins * 1e9), 0.001e18
      );

      assertApproxEqAbs(_aliceRedeemedCollateral, uint256(_aliceCoins).rmul(_collateralBCashPrice), 0.001e18);
      assertApproxEqAbs(_bobRedeemedCollateral, uint256(_bobCoins).rmul(_collateralBCashPrice), 0.001e18);
      assertApproxEqAbs(_carolRedeemedCollateral, uint256(_carolCoins).rmul(_collateralBCashPrice), 0.001e18);

      // NOTE: contract may have some dust left
      assertApproxEqAbs(
        _getCollateralBalance(alice, 'TKN-B') + _getCollateralBalance(bob, 'TKN-B')
          + _getCollateralBalance(carol, 'TKN-B'),
        3 * COLLAT,
        0.001e18
      );
    }

    {
      uint256 _aliceRedeemedCollateral = _redeemCollateral(alice, 'TKN-C', _aliceCoins);
      uint256 _bobRedeemedCollateral = _redeemCollateral(bob, 'TKN-C', _bobCoins);
      uint256 _carolRedeemedCollateral = _redeemCollateral(carol, 'TKN-C', _carolCoins);

      // not all C debt was payed with collateral
      assertEq(globalSettlement.collateralShortfall('TKN-C'), 3e18 + 9e18 + 11e18); // NOTE: calculated above

      uint256 _collateralCCashPrice = globalSettlement.collateralCashPrice('TKN-C');
      uint256 _totalCDebt = ALICE_DEBT + BOB_DEBT + CAROL_DEBT;

      uint256 _collatCPrice = RAY.rdiv(COLLATERAL_C_DROP * 1e9);
      assertEq(globalSettlement.finalCoinPerCollateralPrice('TKN-C'), _collatCPrice);
      assertApproxEqAbs(
        _collateralCCashPrice, ((_totalCDebt * 1e9).rmul(_collatCPrice) - 23e18 * 1e9).rdiv(_totalCoins * 1e9), 0.001e18
      );

      assertApproxEqAbs(_aliceRedeemedCollateral, uint256(_aliceCoins).rmul(_collateralCCashPrice), 0.001e18);
      assertApproxEqAbs(_bobRedeemedCollateral, uint256(_bobCoins).rmul(_collateralCCashPrice), 0.001e18);
      assertApproxEqAbs(_carolRedeemedCollateral, uint256(_carolCoins).rmul(_collateralCCashPrice), 0.001e18);

      // NOTE: contract may have some dust left
      assertApproxEqAbs(
        _getCollateralBalance(alice, 'TKN-C') + _getCollateralBalance(bob, 'TKN-C')
          + _getCollateralBalance(carol, 'TKN-C'),
        3 * COLLAT,
        0.001e18
      );
    }
  }

  function test_global_settlement() public {
    // alice has a safe liquidated for price drop (active collateral auction)
    // bob has a safe liquidated for price drop (active debt auction)
    // carol has a safe that provides surplus (active surplus auction)
    // dave has a healthy active safe

    _generateDebt(alice, address(collateralJoin[WSTETH]), int256(COLLAT), int256(DEBT));
    _generateDebt(bob, address(collateralJoin[WSTETH]), int256(COLLAT), int256(DEBT));
    _generateDebt(carol, address(collateralJoin[WSTETH]), int256(COLLAT), int256(DEBT));

    _setCollateralPrice(WSTETH, TEST_ETH_PRICE_DROP); // price 1 ETH = 100 OD
    _liquidateSAFE(WSTETH, alice);
    accountingEngine.popDebtFromQueue(block.timestamp);
    accountingEngine.auctionDebt(); // active debt auction

    _liquidateSAFE(WSTETH, bob); // active collateral auction
    uint256 _collateralAuction = 1;

    _collectFees(WSTETH, 50 * YEAR);
    accountingEngine.auctionSurplus(); // active surplus auction

    // NOTE: why DEBT/10 not-safe? (price dropped to 1/10)
    _generateDebt(dave, address(collateralJoin[WSTETH]), int256(COLLAT), int256(DEBT / 100)); // active healthy safe

    vm.prank(deployer);
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType(WSTETH);

    globalSettlement.fastTrackAuction(WSTETH, _collateralAuction);

    _freeCollateral(alice, WSTETH);
    _freeCollateral(bob, WSTETH);
    _freeCollateral(carol, WSTETH);
    _freeCollateral(dave, WSTETH);

    accountingEngine.settleDebt(safeEngine.coinBalance(address(accountingEngine)));
    vm.warp(block.timestamp + globalSettlement.params().shutdownCooldown);
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice(WSTETH);

    _prepareCoinsForRedeeming(dave, DEBT / 100);
    _redeemCollateral(dave, WSTETH, DEBT / 100);
  }

  function test_post_settlement_surplus_auction_house() public {
    _generateDebt(alice, address(collateralJoin[WSTETH]), int256(COLLAT), int256(DEBT));
    _collectFees(WSTETH, 50 * YEAR);

    vm.prank(deployer);
    globalSettlement.shutdownSystem();

    accountingEngine.transferPostSettlementSurplus();

    uint256 _auctionId = settlementSurplusAuctioneer.auctionSurplus();
    uint256 _amountToSell = postSettlementSurplusAuctionHouse.auctions(_auctionId).amountToSell;

    uint256 _initialBid = accountingEngine.params().surplusAmount;
    uint256 _bidIncrease = postSettlementSurplusAuctionHouse.params().bidIncrease;
    uint256 _bid = _initialBid * _bidIncrease / 1e18;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), _bid);

    _increasePostSettlementBidSize(address(this), _auctionId, _bid);

    // advance time to settle auction
    vm.warp(block.timestamp + postSettlementSurplusAuctionHouse.params().bidDuration);
    _settlePostSettlementSurplusAuction(address(this), _auctionId);

    assertEq(_getInternalCoinBalance(address(this)), _amountToSell);

    vm.warp(block.timestamp + globalSettlement.params().shutdownCooldown);
    globalSettlement.setOutstandingCoinSupply();

    _prepareCoinsForRedeeming(address(this), _amountToSell / 1e27);
  }

  /// Tests that incrementing a bid while being the top bidder only pulls the increment
  function test_post_settlement_surplus_auction_house_rebid() public {
    _generateDebt(alice, address(collateralJoin[WSTETH]), int256(COLLAT), int256(DEBT));
    _collectFees(WSTETH, 50 * YEAR);

    vm.prank(deployer);
    globalSettlement.shutdownSystem();

    accountingEngine.transferPostSettlementSurplus();

    uint256 _auctionId = settlementSurplusAuctioneer.auctionSurplus();
    uint256 _amountToSell = postSettlementSurplusAuctionHouse.auctions(_auctionId).amountToSell;

    uint256 _initialBid = accountingEngine.params().surplusAmount;
    uint256 _bidIncrease = postSettlementSurplusAuctionHouse.params().bidIncrease;
    uint256 _bid = _initialBid * _bidIncrease / WAD;
    uint256 _rebid = _bid * _bidIncrease / WAD;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), _rebid);

    // Peform the initial bid
    _increasePostSettlementBidSize(address(this), _auctionId, _bid);

    // Increment the bid to check that only the increment is pulled
    // If more than the increment is pulled this reverts due to only having `_rebid` amount of tokens
    _increasePostSettlementBidSize(address(this), _auctionId, _rebid);

    // advance time to settle auction
    vm.warp(block.timestamp + postSettlementSurplusAuctionHouse.params().bidDuration);
    _settlePostSettlementSurplusAuction(address(this), _auctionId);

    assertEq(_getInternalCoinBalance(address(this)), _amountToSell);

    vm.warp(block.timestamp + globalSettlement.params().shutdownCooldown);
    globalSettlement.setOutstandingCoinSupply();

    _prepareCoinsForRedeeming(address(this), _amountToSell / RAY);
  }

  function _multiCollateralSetup() internal {
    _generateDebt(alice, address(collateralJoin['TKN-A']), int256(COLLAT), int256(ALICE_DEBT));
    _generateDebt(alice, address(collateralJoin['TKN-B']), int256(COLLAT), int256(ALICE_DEBT));
    _generateDebt(alice, address(collateralJoin['TKN-C']), int256(COLLAT), int256(ALICE_DEBT));

    _generateDebt(bob, address(collateralJoin['TKN-A']), int256(COLLAT), int256(BOB_DEBT));
    _generateDebt(bob, address(collateralJoin['TKN-B']), int256(COLLAT), int256(BOB_DEBT));
    _generateDebt(bob, address(collateralJoin['TKN-C']), int256(COLLAT), int256(BOB_DEBT));

    _generateDebt(carol, address(collateralJoin['TKN-A']), int256(COLLAT), int256(CAROL_DEBT));
    _generateDebt(carol, address(collateralJoin['TKN-B']), int256(COLLAT), int256(CAROL_DEBT));
    _generateDebt(carol, address(collateralJoin['TKN-C']), int256(COLLAT), int256(CAROL_DEBT));
  }
}

// --- Scoped test contracts ---

// NOTE: missing expectations for lesser decimals ERC20s (for 0 decimals, delta should be 1)
abstract contract E2EGlobalSettlementTestDirectUser is DirectUser, E2EGlobalSettlementTest {}

abstract contract E2EGlobalSettlementTestProxyUser is ProxyUser, E2EGlobalSettlementTest {}
