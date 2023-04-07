// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Params.s.sol';
import './Common.t.sol';

contract E2EGlobalSettlementTest is Common {
  function multiCollateralSetup() public {
    deployment.deployTokenCollateral(
      CollateralParams({
        name: 'TKN-A',
        liquidationPenalty: RAY,
        liquidationQuantity: 100,
        debtCeiling: type(uint256).max,
        safetyCRatio: 1,
        liquidationRatio: 1,
        stabilityFee: 1
      }),
      100
    );

    deployment.deployTokenCollateral(
      CollateralParams({
        name: 'TKN-B',
        liquidationPenalty: RAY,
        liquidationQuantity: 100,
        debtCeiling: type(uint256).max,
        safetyCRatio: 1,
        liquidationRatio: 1,
        stabilityFee: 1
      }),
      1000
    );

    deployment.deployTokenCollateral(
      CollateralParams({
        name: 'TKN-C',
        liquidationPenalty: RAY,
        liquidationQuantity: 100,
        debtCeiling: type(uint256).max,
        safetyCRatio: 1,
        liquidationRatio: 1,
        stabilityFee: 1
      }),
      10_000
    );

    collateral['TKN-A'] = deployment.collateral('TKN-A');
    collateral['TKN-B'] = deployment.collateral('TKN-B');
    collateral['TKN-C'] = deployment.collateral('TKN-C');

    collateral['TKN-A'].mint(alice, 100);
    collateral['TKN-A'].mint(bob, 100);
    collateral['TKN-A'].mint(carol, 100);

    collateral['TKN-B'].mint(alice, 100);
    collateral['TKN-B'].mint(bob, 100);
    collateral['TKN-B'].mint(carol, 100);

    collateral['TKN-C'].mint(alice, 100);
    collateral['TKN-C'].mint(bob, 100);
    collateral['TKN-C'].mint(carol, 100);
  }

  function test_global_settlement_multicollateral() public {
    // TODO: 3 personas, 3 collateral types, 3 price drops
    multiCollateralSetup();
  }

  function test_global_settlement() public {
    // alice has a safe liquidated for price drop (active collateral auction)
    // bob has a safe liquidated for price drop (active debt auction)
    // carol has a safe that provides surplus (active surplus auction)
    // dave has a healthy active safe

    _joinETH(alice, COLLAT);
    _openSafe(alice, int256(COLLAT), int256(DEBT));
    _joinETH(bob, COLLAT);
    _openSafe(bob, int256(COLLAT), int256(DEBT));
    _joinETH(carol, COLLAT);
    _openSafe(carol, int256(COLLAT), int256(DEBT));

    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP); // price 1 ETH = 100 HAI
    liquidationEngine.liquidateSAFE(ETH_A, alice);
    accountingEngine.popDebtFromQueue(block.timestamp);
    uint256 debtAuction = accountingEngine.auctionDebt(); // active debt auction

    uint256 collateralAuction = liquidationEngine.liquidateSAFE(ETH_A, bob); // active collateral auction

    _collectFees(50 * YEAR);
    uint256 surplusAuction = accountingEngine.auctionSurplus(); // active surplus auction

    // NOTE: why DEBT/10 not-safe? (price dropped to 1/10)
    _joinETH(dave, COLLAT);
    _openSafe(dave, int256(COLLAT), int256(DEBT / 100)); // active healthy safe

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
}
