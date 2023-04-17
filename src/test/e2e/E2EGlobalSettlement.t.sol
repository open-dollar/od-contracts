// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Params.s.sol';
import './Common.t.sol';
import {Math} from '@libraries/Math.sol';

contract E2EGlobalSettlementTest is Common {
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

    // NOTE: all collaterals have COLLATERAL_PRICE
    // alice has a 20% LTV
    (uint256 _aliceCollateral, uint256 _aliceDebt) = safeEngine.safes('TKN-A', alice);
    assertEq(_aliceDebt.rdiv(_aliceCollateral * COLLATERAL_PRICE), 0.2e9);

    // bob has a 50% LTV
    (uint256 _bobCollateral, uint256 _bobDebt) = safeEngine.safes('TKN-A', bob);
    assertEq(_bobDebt.rdiv(_bobCollateral * COLLATERAL_PRICE), 0.5e9);

    // carol has a 60% LTV
    (uint256 _carolCollateral, uint256 _carolDebt) = safeEngine.safes('TKN-A', carol);
    assertEq(_carolDebt.rdiv(_carolCollateral * COLLATERAL_PRICE), 0.6e9);

    // NOTE: now B and C collaterals have less value
    oracle['TKN-B'].setPriceAndValidity(COLLATERAL_B_DROP, true); // price 1 TKN-B = 75 HAI
    oracleRelayer.updateCollateralPrice('TKN-B');
    oracle['TKN-C'].setPriceAndValidity(COLLATERAL_C_DROP, true); // price 1 TKN-C = 5 HAI
    oracleRelayer.updateCollateralPrice('TKN-C');

    vm.prank(deployer);
    globalSettlement.shutdownSystem();

    uint256 _totalAToRedeem;
    uint256 _totalBToRedeem;
    uint256 _totalCToRedeem;

    /* COLLATERAL TKN-A (maintained price) */
    globalSettlement.freezeCollateralType('TKN-A');
    globalSettlement.processSAFE('TKN-A', alice);
    globalSettlement.processSAFE('TKN-A', bob);
    globalSettlement.processSAFE('TKN-A', carol);

    {
      // alice can take 80% of TKN-A collateral
      uint256 _aliceARemainder = _releaseRemainingCollateral(alice, 'TKN-A');
      assertEq(_aliceARemainder, 0.8e18);

      // bob can take 50% of TKN-A collateral
      uint256 _bobARemainder = _releaseRemainingCollateral(bob, 'TKN-A');
      assertEq(_bobARemainder, 0.5e18);

      // carol can take 40% of TKN-A collateral
      uint256 _carolARemainder = _releaseRemainingCollateral(carol, 'TKN-A');
      assertEq(_carolARemainder, 0.4e18);

      _totalAToRedeem = 3 * COLLAT - (_aliceARemainder + _bobARemainder + _carolARemainder);
    }

    /* COLLATERAL TKN-B (price dropped 25%) */
    globalSettlement.freezeCollateralType('TKN-B');
    globalSettlement.processSAFE('TKN-B', alice);
    globalSettlement.processSAFE('TKN-B', bob);
    globalSettlement.processSAFE('TKN-B', carol);

    {
      /**
       * alice debt = 20 HAI
       * alice collateral = 1 TKN-B = 75 HAI
       * alice pays debt with (20/75) = 0.266 TKN-B
       * alice has 0.733 TKN-B left
       * alice can take 73% of TKN-B collateral
       */
      uint256 _aliceBRemainder = _releaseRemainingCollateral(alice, 'TKN-B');
      assertAlmostEq(_aliceBRemainder, 0.733e18, 0.001e18);

      // bob can take 33% of TKN-B collateral
      uint256 _bobBRemainder = _releaseRemainingCollateral(bob, 'TKN-B');
      assertAlmostEq(_bobBRemainder, 0.333e18, 0.001e18);

      // carol can take 20% of TKN-B collateral
      uint256 _carolBRemainder = _releaseRemainingCollateral(carol, 'TKN-B');
      assertAlmostEq(_carolBRemainder, 0.2e18, 0.001e18);

      _totalBToRedeem = 3 * COLLAT - (_aliceBRemainder + _bobBRemainder + _carolBRemainder);
    }

    /* COLLATERAL TKN-C (price dropped 95%) */
    globalSettlement.freezeCollateralType('TKN-C');

    /**
     * alice debt = 20 HAI
     * alice collateral = 1 TKN-C = 5 HAI
     * alice must pay debt with (20/5) = 4 TKN-C
     * alice is short 3 TKN-C
     */
    globalSettlement.processSAFE('TKN-C', alice);
    assertAlmostEq(globalSettlement.collateralShortfall('TKN-C'), 3e18, 0.001e18);

    /**
     * bob debt = 50 HAI
     * bob collateral = 1 TKN-C = 5 HAI
     * bob must pay debt with (50/5) = 10 TKN-C
     * bob is short 9 TKN-C
     */
    globalSettlement.processSAFE('TKN-C', bob);
    assertAlmostEq(globalSettlement.collateralShortfall('TKN-C'), 3e18 + 9e18, 0.001e18);

    /**
     * carol debt = 60 HAI
     * carol collateral = 1 TKN-C = 5 HAI
     * carol must pay debt with (60/5) = 12 TKN-C
     * carol is short 11 TKN-C
     */
    globalSettlement.processSAFE('TKN-C', carol);
    assertAlmostEq(globalSettlement.collateralShortfall('TKN-C'), 3e18 + 9e18 + 11e18, 0.001e18);

    {
      /**
       * alice debt = 20 HAI
       * alice collateral = 1 TKN-C = 5 HAI
       * alice must pay debt with (20/5) = 4 TKN-C
       * alice has 0 TKN-C left
       * bob has 0 TKN-C left (higher debt)
       * carol has 0 TKN-C left (even higher debt)
       */
      uint256 _aliceCRemainder = _releaseRemainingCollateral(alice, 'TKN-C');
      assertEq(_aliceCRemainder, 0);
      uint256 _bobCRemainder = _releaseRemainingCollateral(bob, 'TKN-C');
      assertEq(_bobCRemainder, 0);
      uint256 _carolCRemainder = _releaseRemainingCollateral(carol, 'TKN-C');
      assertEq(_carolCRemainder, 0);

      _totalCToRedeem = 3 * COLLAT - (_aliceCRemainder + _bobCRemainder + _carolCRemainder);
    }

    /* SETTLEMENT */
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice('TKN-A');
    globalSettlement.calculateCashPrice('TKN-B');
    globalSettlement.calculateCashPrice('TKN-C');

    // alice bob and carol redeem their HAI
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
      assertAlmostEq(_collateralACashPrice, (_totalADebt * 1e9).rmul(_collatAPrice).rdiv(_totalCoins * 1e9), 0.001e18);

      assertAlmostEq(_aliceRedeemedCollateral, uint256(_aliceCoins).rmul(_collateralACashPrice), 0.001e18);
      assertAlmostEq(_bobRedeemedCollateral, uint256(_bobCoins).rmul(_collateralACashPrice), 0.001e18);
      assertAlmostEq(_carolRedeemedCollateral, uint256(_carolCoins).rmul(_collateralACashPrice), 0.001e18);

      // NOTE: contract may have some dust left
      assertAlmostEq(
        collateral['TKN-A'].balanceOf(alice) + collateral['TKN-A'].balanceOf(bob) + collateral['TKN-A'].balanceOf(carol),
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
      assertAlmostEq(_collateralBCashPrice, (_totalBDebt * 1e9).rmul(_collatBPrice).rdiv(_totalCoins * 1e9), 0.001e18);

      assertAlmostEq(_aliceRedeemedCollateral, uint256(_aliceCoins).rmul(_collateralBCashPrice), 0.001e18);
      assertAlmostEq(_bobRedeemedCollateral, uint256(_bobCoins).rmul(_collateralBCashPrice), 0.001e18);
      assertAlmostEq(_carolRedeemedCollateral, uint256(_carolCoins).rmul(_collateralBCashPrice), 0.001e18);

      // NOTE: contract may have some dust left
      assertAlmostEq(
        collateral['TKN-B'].balanceOf(alice) + collateral['TKN-B'].balanceOf(bob) + collateral['TKN-B'].balanceOf(carol),
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
      assertAlmostEq(
        _collateralCCashPrice, ((_totalCDebt * 1e9).rmul(_collatCPrice) - 23e18 * 1e9).rdiv(_totalCoins * 1e9), 0.001e18
      );

      assertAlmostEq(_aliceRedeemedCollateral, uint256(_aliceCoins).rmul(_collateralCCashPrice), 0.001e18);
      assertAlmostEq(_bobRedeemedCollateral, uint256(_bobCoins).rmul(_collateralCCashPrice), 0.001e18);
      assertAlmostEq(_carolRedeemedCollateral, uint256(_carolCoins).rmul(_collateralCCashPrice), 0.001e18);

      // NOTE: contract may have some dust left
      assertAlmostEq(
        collateral['TKN-C'].balanceOf(alice) + collateral['TKN-C'].balanceOf(bob) + collateral['TKN-C'].balanceOf(carol),
        3 * COLLAT,
        0.001e18
      );
    }

    emit LogNamedUint256('alice A', collateral['TKN-A'].balanceOf(alice));
    emit LogNamedUint256('bob A', collateral['TKN-A'].balanceOf(bob));
    emit LogNamedUint256('carol A', collateral['TKN-A'].balanceOf(carol));

    emit LogNamedUint256('alice B', collateral['TKN-B'].balanceOf(alice));
    emit LogNamedUint256('bob B', collateral['TKN-B'].balanceOf(bob));
    emit LogNamedUint256('carol B', collateral['TKN-B'].balanceOf(carol));

    emit LogNamedUint256('alice C', collateral['TKN-C'].balanceOf(alice));
    emit LogNamedUint256('bob C', collateral['TKN-C'].balanceOf(bob));
    emit LogNamedUint256('carol C', collateral['TKN-C'].balanceOf(carol));
  }

  function test_global_settlement() public {
    // alice has a safe liquidated for price drop (active collateral auction)
    // bob has a safe liquidated for price drop (active debt auction)
    // carol has a safe that provides surplus (active surplus auction)
    // dave has a healthy active safe

    _joinETH(alice, COLLAT);
    _openSafe(alice, address(ethJoin), int256(COLLAT), int256(DEBT));
    _joinETH(bob, COLLAT);
    _openSafe(bob, address(ethJoin), int256(COLLAT), int256(DEBT));
    _joinETH(carol, COLLAT);
    _openSafe(carol, address(ethJoin), int256(COLLAT), int256(DEBT));

    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP); // price 1 ETH = 100 HAI
    liquidationEngine.liquidateSAFE(ETH_A, alice);
    accountingEngine.popDebtFromQueue(block.timestamp);
    uint256 debtAuction = accountingEngine.auctionDebt(); // active debt auction

    uint256 collateralAuction = liquidationEngine.liquidateSAFE(ETH_A, bob); // active collateral auction

    _collectFees(50 * YEAR);
    uint256 surplusAuction = accountingEngine.auctionSurplus(); // active surplus auction

    // NOTE: why DEBT/10 not-safe? (price dropped to 1/10)
    _joinETH(dave, COLLAT);
    _openSafe(dave, address(ethJoin), int256(COLLAT), int256(DEBT / 100)); // active healthy safe

    vm.prank(deployer);
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType(ETH_A);

    // TODO: test reverts before processSAFE
    globalSettlement.processSAFE(ETH_A, alice);
    globalSettlement.processSAFE(ETH_A, bob);
    globalSettlement.processSAFE(ETH_A, carol);
    globalSettlement.processSAFE(ETH_A, dave);

    globalSettlement.fastTrackAuction(ETH_A, collateralAuction);

    vm.prank(alice);
    globalSettlement.freeCollateral(ETH_A);
    vm.prank(bob);
    vm.expectRevert(); // bob's safe has debt (bc fastTrackAuction?)
    globalSettlement.freeCollateral(ETH_A);
    vm.prank(carol);
    globalSettlement.freeCollateral(ETH_A);
    vm.prank(dave);
    globalSettlement.freeCollateral(ETH_A);

    // TODO: add cooldowns in deploy
    accountingEngine.settleDebt(safeEngine.coinBalance(address(accountingEngine)));
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice(ETH_A);

    // TODO: add expectations for each persona
    vm.startPrank(dave);
    safeEngine.approveSAFEModification(address(globalSettlement));
    globalSettlement.prepareCoinsForRedeeming(DEBT / 100);
    globalSettlement.redeemCollateral(ETH_A, DEBT / 100);
    vm.stopPrank();
  }

  function _multiCollateralSetup() internal {
    deployment.deployTokenCollateral(
      CollateralParams({
        name: 'TKN-A',
        liquidationPenalty: RAY,
        liquidationQuantity: LIQUIDATION_QUANTITY,
        debtCeiling: type(uint256).max,
        safetyCRatio: LIQUIDATION_RATIO,
        liquidationRatio: LIQUIDATION_RATIO,
        stabilityFee: RAY
      }),
      COLLATERAL_PRICE
    );

    deployment.deployTokenCollateral(
      CollateralParams({
        name: 'TKN-B',
        liquidationPenalty: RAY,
        liquidationQuantity: LIQUIDATION_QUANTITY,
        debtCeiling: type(uint256).max,
        safetyCRatio: LIQUIDATION_RATIO,
        liquidationRatio: LIQUIDATION_RATIO,
        stabilityFee: 0
      }),
      COLLATERAL_PRICE
    );

    deployment.deployTokenCollateral(
      CollateralParams({
        name: 'TKN-C',
        liquidationPenalty: RAY,
        liquidationQuantity: LIQUIDATION_QUANTITY,
        debtCeiling: type(uint256).max,
        safetyCRatio: LIQUIDATION_RATIO,
        liquidationRatio: LIQUIDATION_RATIO,
        stabilityFee: 0
      }),
      COLLATERAL_PRICE
    );

    safeEngine = deployment.safeEngine();
    collateral['TKN-A'] = deployment.collateral('TKN-A');
    collateral['TKN-B'] = deployment.collateral('TKN-B');
    collateral['TKN-C'] = deployment.collateral('TKN-C');
    collateralJoin['TKN-A'] = deployment.collateralJoin('TKN-A');
    collateralJoin['TKN-B'] = deployment.collateralJoin('TKN-B');
    collateralJoin['TKN-C'] = deployment.collateralJoin('TKN-C');
    oracle['TKN-A'] = deployment.oracle('TKN-A');
    oracle['TKN-B'] = deployment.oracle('TKN-B');
    oracle['TKN-C'] = deployment.oracle('TKN-C');
    oracleRelayer = deployment.oracleRelayer();

    _joinTKN(alice, collateralJoin['TKN-A'], COLLAT);
    _joinTKN(alice, collateralJoin['TKN-B'], COLLAT);
    _joinTKN(alice, collateralJoin['TKN-C'], COLLAT);
    _openSafe(alice, address(collateralJoin['TKN-A']), int256(COLLAT), int256(ALICE_DEBT));
    _openSafe(alice, address(collateralJoin['TKN-B']), int256(COLLAT), int256(ALICE_DEBT));
    _openSafe(alice, address(collateralJoin['TKN-C']), int256(COLLAT), int256(ALICE_DEBT));

    _joinTKN(bob, collateralJoin['TKN-A'], COLLAT);
    _joinTKN(bob, collateralJoin['TKN-B'], COLLAT);
    _joinTKN(bob, collateralJoin['TKN-C'], COLLAT);
    _openSafe(bob, address(collateralJoin['TKN-A']), int256(COLLAT), int256(BOB_DEBT));
    _openSafe(bob, address(collateralJoin['TKN-B']), int256(COLLAT), int256(BOB_DEBT));
    _openSafe(bob, address(collateralJoin['TKN-C']), int256(COLLAT), int256(BOB_DEBT));

    _joinTKN(carol, collateralJoin['TKN-A'], COLLAT);
    _joinTKN(carol, collateralJoin['TKN-B'], COLLAT);
    _joinTKN(carol, collateralJoin['TKN-C'], COLLAT);
    _openSafe(carol, address(collateralJoin['TKN-A']), int256(COLLAT), int256(CAROL_DEBT));
    _openSafe(carol, address(collateralJoin['TKN-B']), int256(COLLAT), int256(CAROL_DEBT));
    _openSafe(carol, address(collateralJoin['TKN-C']), int256(COLLAT), int256(CAROL_DEBT));
  }

  function _releaseRemainingCollateral(
    address _account,
    bytes32 _collateralType
  ) internal returns (uint256 _remainderCollateral) {
    (_remainderCollateral,) = safeEngine.safes(_collateralType, _account);
    if (_remainderCollateral > 0) {
      vm.startPrank(_account);
      globalSettlement.freeCollateral(_collateralType);
      collateralJoin[_collateralType].exit(_account, _remainderCollateral);
      assertEq(collateral[_collateralType].balanceOf(_account), _remainderCollateral);
      vm.stopPrank();
    }
  }

  function _prepareCoinsForRedeeming(address _account, uint256 _amount) internal {
    vm.startPrank(_account);
    safeEngine.approveSAFEModification(address(globalSettlement));
    globalSettlement.prepareCoinsForRedeeming(_amount);
    vm.stopPrank();
  }

  function _redeemCollateral(
    address _account,
    bytes32 _collateralType,
    uint256 _coinsAmount
  ) internal returns (uint256 _collateralAmount) {
    vm.startPrank(_account);
    globalSettlement.redeemCollateral(_collateralType, _coinsAmount);
    _collateralAmount = safeEngine.tokenCollateral(_collateralType, _account);
    collateralJoin[_collateralType].exit(_account, _collateralAmount);
    vm.stopPrank();
  }
}
