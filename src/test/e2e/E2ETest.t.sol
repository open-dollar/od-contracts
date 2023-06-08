// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Common, COLLAT, DEBT, TEST_ETH_PRICE_DROP, RAD_DELTA} from './Common.t.sol';

import {ETH_A, SURPLUS_AUCTION_BID_RECEIVER} from '@script/Params.s.sol';
import {
  INITIAL_DEBT_AUCTION_MINTED_TOKENS,
  ONE_HUNDRED_COINS,
  PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY
} from '@test/e2e/TestParams.s.sol';

import {Math, RAY, YEAR} from '@libraries/Math.sol';

uint256 constant TEST_ETH_A_SF_APR = 1.05e18; // 5%/yr

contract E2ETest is Common {
  using Math for uint256;

  function test_open_safe() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));

    (uint256 _generatedDebt, uint256 _lockedCollateral) = _getSafeStatus(ETH_A, address(this));
    assertEq(_generatedDebt, DEBT);
    assertEq(_lockedCollateral, COLLAT);
  }

  function test_exit_join() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));

    assertEq(coin.balanceOf(address(this)), DEBT);
  }

  function test_stability_fee() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));

    uint256 _globalDebt;
    _globalDebt = safeEngine.globalDebt();
    assertEq(_globalDebt, DEBT * RAY); // RAD

    vm.warp(block.timestamp + YEAR);
    taxCollector.taxSingle(ETH_A);

    uint256 _globalDebtAfterTax = safeEngine.globalDebt();
    assertApproxEqAbs(_globalDebtAfterTax, Math.wmul(DEBT, TEST_ETH_A_SF_APR) * RAY, RAD_DELTA); // RAD

    uint256 _accountingEngineCoins =
      safeEngine.coinBalance(address(accountingEngine)).rmul(100 * RAY).rdiv(PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY);
    assertEq(_accountingEngineCoins, _globalDebtAfterTax - _globalDebt);
  }

  function test_liquidation() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));

    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP);

    _liquidateSAFE(ETH_A, address(this));

    assertEq(safeEngine.safes(ETH_A, address(this)).lockedCollateral, 0);
    assertEq(safeEngine.safes(ETH_A, address(this)).generatedDebt, 0);
  }

  function test_liquidation_by_price_drop() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));

    // NOTE: LVT for price = 1000 is 50%
    _setCollateralPrice(ETH_A, 675e18); // LVT = 74,0% = 1/1.35

    // vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    // _liquidateSAFE(ETH_A, address(this));

    _setCollateralPrice(ETH_A, 674e18); // LVT = 74,1% > 1/1.35
    _liquidateSAFE(ETH_A, address(this));
  }

  function test_liquidation_by_fees() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));

    _collectFees(8 * YEAR); // 1.05^8 = 148%

    // TODO: fix liquidation test for E2EProxy implementation
    // vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    // _liquidateSAFE(ETH_A, address(this));

    _collectFees(YEAR); // 1.05^9 = 153%
    _liquidateSAFE(ETH_A, address(this));
  }

  function test_collateral_auction() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP);
    _liquidateSAFE(ETH_A, address(this));

    uint256 _discount = collateralAuctionHouse[ETH_A].cParams().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP);
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[ETH_A].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT);

    _joinCoins(address(this), _amountToBid);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse[ETH_A]));
    collateralAuctionHouse[ETH_A].buyCollateral(1, _amountToBid);

    // NOTE: auctions(1) is deleted
    uint256 _amountToSell = collateralAuctionHouse[ETH_A].auctions(1).amountToSell;
    assertEq(_amountToSell, 0);
  }

  function test_collateral_auction_partial() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP);
    _liquidateSAFE(ETH_A, address(this));

    uint256 _discount = collateralAuctionHouse[ETH_A].cParams().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP) / 2;
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[ETH_A].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT / 2);

    _joinCoins(address(this), _amountToBid);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse[ETH_A]));
    collateralAuctionHouse[ETH_A].buyCollateral(1, _amountToBid);

    // NOTE: auctions(1) is NOT deleted
    uint256 _amountToSell = collateralAuctionHouse[ETH_A].auctions(1).amountToSell;
    assertGt(_amountToSell, 0);
  }

  function test_debt_auction() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(ETH_A, TEST_ETH_PRICE_DROP);
    _liquidateSAFE(ETH_A, address(this));

    accountingEngine.popDebtFromQueue(block.timestamp);
    accountingEngine.auctionDebt();

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder,, uint48 _auctionDeadline) =
      debtAuctionHouse.bids(1);
    assertEq(_bidAmount, ONE_HUNDRED_COINS);
    assertEq(_amountToSell, INITIAL_DEBT_AUCTION_MINTED_TOKENS);
    assertEq(_highBidder, address(accountingEngine));

    _joinCoins(address(this), _bidAmount / RAY);

    uint256 _deltaCoinBalance = safeEngine.coinBalance(address(this));
    uint256 _bidDecrease = debtAuctionHouse.params().bidDecrease;
    uint256 _tokenAmount = Math.wdiv(INITIAL_DEBT_AUCTION_MINTED_TOKENS, _bidDecrease);

    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    debtAuctionHouse.decreaseSoldAmount(1, _tokenAmount, ONE_HUNDRED_COINS);

    (_bidAmount, _amountToSell, _highBidder,,) = debtAuctionHouse.bids(1);
    assertEq(_bidAmount, ONE_HUNDRED_COINS);
    assertEq(_amountToSell, _tokenAmount);
    assertEq(_highBidder, address(this));

    vm.warp(_auctionDeadline);
    debtAuctionHouse.settleAuction(1);

    _deltaCoinBalance -= safeEngine.coinBalance(address(this));
    assertEq(_deltaCoinBalance, ONE_HUNDRED_COINS);
    assertEq(protocolToken.balanceOf(address(this)), _tokenAmount);
  }

  function test_surplus_auction() public {
    _generateDebt(address(this), address(collateralJoin[ETH_A]), int256(COLLAT), int256(DEBT));
    uint256 INITIAL_BID = 1e18;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), INITIAL_BID);

    // generate surplus
    _collectFees(10 * YEAR);

    accountingEngine.auctionSurplus();

    uint256 _delay = (surplusAuctionHouse.params()).totalAuctionLength;
    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder,, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(1);
    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, ONE_HUNDRED_COINS);
    assertEq(_highBidder, address(accountingEngine));
    assertEq(_auctionDeadline, block.timestamp + _delay);

    protocolToken.approve(address(surplusAuctionHouse), INITIAL_BID);
    surplusAuctionHouse.increaseBidSize(1, ONE_HUNDRED_COINS, INITIAL_BID);

    (_bidAmount, _amountToSell, _highBidder,,) = surplusAuctionHouse.bids(1);
    assertEq(_bidAmount, INITIAL_BID);
    assertEq(_highBidder, address(this));

    vm.warp(_auctionDeadline);

    assertEq(protocolToken.totalSupply(), INITIAL_BID);
    surplusAuctionHouse.settleAuction(1);
    assertEq(protocolToken.totalSupply(), INITIAL_BID / 2); // 50% of the bid is burned
    assertEq(protocolToken.balanceOf(SURPLUS_AUCTION_BID_RECEIVER), INITIAL_BID / 2); // 50% is sent to the receiver
    assertEq(protocolToken.balanceOf(address(this)), 0);
  }
}
