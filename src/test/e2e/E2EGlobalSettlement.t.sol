// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Params.s.sol';
import './Common.t.sol';
import {Math} from '@libraries/Math.sol';

contract E2EGlobalSettlementTest is Common {
  using Math for uint256;

  uint256 LIQUIDATION_QUANTITY = 1000e45;
  uint256 COLLATERAL_PRICE = 100e18;
  uint256 LIQUIDATION_RATIO = 1.5e27;

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
    oracle['TKN-B'].setPriceAndValidity(75e18, true); // price 1 TKN-B = 75 HAI
    oracle['TKN-C'].setPriceAndValidity(5e18, true); // price 1 TKN-C = 5 HAI
    oracleRelayer.updateCollateralPrice('TKN-B');
    oracleRelayer.updateCollateralPrice('TKN-C');

    vm.prank(deployer);
    globalSettlement.shutdownSystem();

    /* COLLATERAL TKN-A (maintained price) */
    globalSettlement.freezeCollateralType('TKN-A');
    globalSettlement.processSAFE('TKN-A', alice);
    globalSettlement.processSAFE('TKN-A', bob);
    globalSettlement.processSAFE('TKN-A', carol);

    // alice can take 80% of TKN-A collateral
    uint256 _aliceARemainter = _releaseRemainingCollateral(alice, 'TKN-A');
    assertEq(_aliceARemainter, 0.8e18);

    // bob can take 50% of TKN-A collateral
    uint256 _bobARemainder = _releaseRemainingCollateral(bob, 'TKN-A');
    assertEq(_bobARemainder, 0.5e18);

    // carol can take 40% of TKN-A collateral
    uint256 _carolARemainder = _releaseRemainingCollateral(carol, 'TKN-A');
    assertEq(_carolARemainder, 0.4e18);

    /* COLLATERAL TKN-B (price dropped 25%) */
    globalSettlement.freezeCollateralType('TKN-B');
    globalSettlement.processSAFE('TKN-B', alice);
    globalSettlement.processSAFE('TKN-B', bob);
    globalSettlement.processSAFE('TKN-B', carol);

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

    /* COLLATERAL TKN-C (price dropped 95%) */
    globalSettlement.freezeCollateralType('TKN-C');
    globalSettlement.processSAFE('TKN-C', alice);
    globalSettlement.processSAFE('TKN-C', bob);
    globalSettlement.processSAFE('TKN-C', carol);

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

    _joinTKN(alice, collateralJoin['TKN-A'], 100e18);
    _joinTKN(alice, collateralJoin['TKN-B'], 100e18);
    _joinTKN(alice, collateralJoin['TKN-C'], 100e18);
    _openSafe(alice, address(collateralJoin['TKN-A']), int256(COLLAT), int256(20e18));
    _openSafe(alice, address(collateralJoin['TKN-B']), int256(COLLAT), int256(20e18));
    _openSafe(alice, address(collateralJoin['TKN-C']), int256(COLLAT), int256(20e18));

    _joinTKN(bob, collateralJoin['TKN-A'], 100e18);
    _joinTKN(bob, collateralJoin['TKN-B'], 100e18);
    _joinTKN(bob, collateralJoin['TKN-C'], 100e18);
    _openSafe(bob, address(collateralJoin['TKN-A']), int256(COLLAT), int256(50e18));
    _openSafe(bob, address(collateralJoin['TKN-B']), int256(COLLAT), int256(50e18));
    _openSafe(bob, address(collateralJoin['TKN-C']), int256(COLLAT), int256(50e18));

    _joinTKN(carol, collateralJoin['TKN-A'], 100e18);
    _joinTKN(carol, collateralJoin['TKN-B'], 100e18);
    _joinTKN(carol, collateralJoin['TKN-C'], 100e18);
    _openSafe(carol, address(collateralJoin['TKN-A']), int256(COLLAT), int256(60e18));
    _openSafe(carol, address(collateralJoin['TKN-B']), int256(COLLAT), int256(60e18));
    _openSafe(carol, address(collateralJoin['TKN-C']), int256(COLLAT), int256(60e18));
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
}
