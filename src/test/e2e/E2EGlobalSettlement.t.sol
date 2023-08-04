// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Common, COLLAT, DEBT, TEST_ETH_PRICE_DROP} from './Common.t.sol';
import {Math} from '@libraries/Math.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ETH_A, HAI_INITIAL_PRICE} from '@script/Params.s.sol';
import {RAY, YEAR} from '@libraries/Math.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';

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

    assertEq(oracleRelayer.redemptionPrice(), HAI_INITIAL_PRICE * 1e9);

    // NOTE: all collaterals have COLLATERAL_PRICE
    // alice has a 20% LTV
    ISAFEEngine.SAFE memory _aliceSafe = safeEngine.safes('TKN-A', alice);
    assertEq(_aliceSafe.generatedDebt.rdiv(_aliceSafe.lockedCollateral * COLLATERAL_PRICE), 0.2e9);

    // bob has a 50% LTV
    ISAFEEngine.SAFE memory _bobSafe = safeEngine.safes('TKN-A', bob);
    assertEq(_bobSafe.generatedDebt.rdiv(_bobSafe.lockedCollateral * COLLATERAL_PRICE), 0.5e9);

    // carol has a 60% LTV
    ISAFEEngine.SAFE memory _carolSafe = safeEngine.safes('TKN-A', carol);
    assertEq(_carolSafe.generatedDebt.rdiv(_carolSafe.lockedCollateral * COLLATERAL_PRICE), 0.6e9);

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
      assertApproxEqAbs(_aliceBRemainder, 0.733e18, 0.001e18);

      // bob can take 33% of TKN-B collateral
      uint256 _bobBRemainder = _releaseRemainingCollateral(bob, 'TKN-B');
      assertApproxEqAbs(_bobBRemainder, 0.333e18, 0.001e18);

      // carol can take 20% of TKN-B collateral
      uint256 _carolBRemainder = _releaseRemainingCollateral(carol, 'TKN-B');
      assertApproxEqAbs(_carolBRemainder, 0.2e18, 0.001e18);

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
    assertApproxEqAbs(globalSettlement.collateralShortfall('TKN-C'), 3e18, 0.001e18);

    /**
     * bob debt = 50 HAI
     * bob collateral = 1 TKN-C = 5 HAI
     * bob must pay debt with (50/5) = 10 TKN-C
     * bob is short 9 TKN-C
     */
    globalSettlement.processSAFE('TKN-C', bob);
    assertApproxEqAbs(globalSettlement.collateralShortfall('TKN-C'), 3e18 + 9e18, 0.001e18);

    /**
     * carol debt = 60 HAI
     * carol collateral = 1 TKN-C = 5 HAI
     * carol must pay debt with (60/5) = 12 TKN-C
     * carol is short 11 TKN-C
     */
    globalSettlement.processSAFE('TKN-C', carol);
    assertApproxEqAbs(globalSettlement.collateralShortfall('TKN-C'), 3e18 + 9e18 + 11e18, 0.001e18);

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

    _generateDebt(alice, address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));
    _generateDebt(bob, address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));
    _generateDebt(carol, address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));

    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP); // price 1 ETH = 100 HAI
    liquidationEngine.liquidateSAFE(ETH_A, alice);
    accountingEngine.popDebtFromQueue(block.timestamp);
    accountingEngine.auctionDebt(); // active debt auction

    uint256 collateralAuction = liquidationEngine.liquidateSAFE(ETH_A, bob); // active collateral auction

    _collectFees(ETH_A, 50 * YEAR);
    accountingEngine.auctionSurplus(); // active surplus auction

    // NOTE: why DEBT/10 not-safe? (price dropped to 1/10)
    _generateDebt(dave, address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT / 100)); // active healthy safe

    vm.prank(deployer);
    globalSettlement.shutdownSystem();
    globalSettlement.freezeCollateralType(ETH_A);

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

    accountingEngine.settleDebt(safeEngine.coinBalance(address(accountingEngine)));
    globalSettlement.setOutstandingCoinSupply();
    globalSettlement.calculateCashPrice(ETH_A);

    vm.startPrank(dave);
    safeEngine.approveSAFEModification(address(globalSettlement));
    globalSettlement.prepareCoinsForRedeeming(DEBT / 100);
    globalSettlement.redeemCollateral(ETH_A, DEBT / 100);
    vm.stopPrank();
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

  function _releaseRemainingCollateral(
    address _account,
    bytes32 _cType
  ) internal returns (uint256 _remainderCollateral) {
    _remainderCollateral = safeEngine.safes(_cType, _account).lockedCollateral;
    if (_remainderCollateral > 0) {
      vm.startPrank(_account);
      globalSettlement.freeCollateral(_cType);
      vm.stopPrank();
      _exitCollateral(_account, address(collateralJoin[_cType]), _remainderCollateral);
      assertEq(_getCollateralBalance(_account, _cType), _remainderCollateral);
    }
  }

  function _prepareCoinsForRedeeming(address _account, uint256 _amount) internal {
    _joinCoins(_account, _amount); // has prank
    vm.startPrank(_account);
    safeEngine.approveSAFEModification(address(globalSettlement));
    globalSettlement.prepareCoinsForRedeeming(_amount);
    vm.stopPrank();
  }

  function _redeemCollateral(
    address _account,
    bytes32 _cType,
    uint256 _coinsAmount
  ) internal returns (uint256 _collateralAmount) {
    vm.startPrank(_account);
    globalSettlement.redeemCollateral(_cType, _coinsAmount);
    _collateralAmount = safeEngine.tokenCollateral(_cType, _account);
    vm.stopPrank();
    _exitCollateral(_account, address(collateralJoin[_cType]), _collateralAmount);
  }
}

// --- Scoped test contracts ---

// NOTE: missing expectations for lesser decimals ERC20s (for 0 decimals, delta should be 1)
contract E2EGlobalSettlementTestDirectUser is DirectUser, E2EGlobalSettlementTest {}

// NOTE: unimplemented
// contract E2EGlobalSettlementTestProxyUser is ProxyUser, E2EGlobalSettlementTest {}
