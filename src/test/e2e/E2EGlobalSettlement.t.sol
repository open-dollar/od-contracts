// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Params.s.sol';
import './Common.t.sol';

contract E2EGlobalSettlementTest is Common {
  function test_global_settlement_multicollateral() public {
    _multiCollateralSetup();
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
    uint256 LIQUIDATION_QUANTITY = 1000e45;
    uint256 COLLATERAL_PRICE = 100e18;
    uint256 LIQUIDATION_RATIO = 1.5e27;

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

    collateral['TKN-A'] = deployment.collateral('TKN-A');
    collateral['TKN-B'] = deployment.collateral('TKN-B');
    collateral['TKN-C'] = deployment.collateral('TKN-C');

    collateralJoin['TKN-A'] = deployment.collateralJoin('TKN-A');
    collateralJoin['TKN-B'] = deployment.collateralJoin('TKN-B');
    collateralJoin['TKN-C'] = deployment.collateralJoin('TKN-C');

    _joinTKN(alice, collateralJoin['TKN-A'], 100e18);
    _joinTKN(alice, collateralJoin['TKN-B'], 100e18);
    _joinTKN(alice, collateralJoin['TKN-C'], 100e18);
    _openSafe(alice, address(collateralJoin['TKN-A']), int256(COLLAT), int256(20e18));
    _openSafe(alice, address(collateralJoin['TKN-B']), int256(COLLAT), int256(20e18));
    _openSafe(alice, address(collateralJoin['TKN-C']), int256(COLLAT), int256(20e18));

    // assert alice LTV is 20%

    _joinTKN(bob, collateralJoin['TKN-A'], 100e18);
    _joinTKN(bob, collateralJoin['TKN-B'], 100e18);
    _joinTKN(bob, collateralJoin['TKN-C'], 100e18);
    _openSafe(bob, address(collateralJoin['TKN-A']), int256(COLLAT), int256(50e18));
    _openSafe(bob, address(collateralJoin['TKN-B']), int256(COLLAT), int256(50e18));
    _openSafe(bob, address(collateralJoin['TKN-C']), int256(COLLAT), int256(50e18));

    // assert bob LTV is 50%

    _joinTKN(carol, collateralJoin['TKN-A'], 100e18);
    _joinTKN(carol, collateralJoin['TKN-B'], 100e18);
    _joinTKN(carol, collateralJoin['TKN-C'], 100e18);
    _openSafe(carol, address(collateralJoin['TKN-A']), int256(COLLAT), int256(60e18));
    _openSafe(carol, address(collateralJoin['TKN-B']), int256(COLLAT), int256(60e18));
    _openSafe(carol, address(collateralJoin['TKN-C']), int256(COLLAT), int256(60e18));

    // assert carol LTV is 60%
  }
}
