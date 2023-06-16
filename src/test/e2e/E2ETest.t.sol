// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Common, COLLAT, DEBT, TEST_ETH_PRICE_DROP, RAD_DELTA} from './Common.t.sol';

import {SURPLUS_AUCTION_BID_RECEIVER} from '@script/Params.s.sol';
import {
  INITIAL_DEBT_AUCTION_MINTED_TOKENS,
  ONE_HUNDRED_COINS,
  PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY
} from '@test/e2e/TestParams.s.sol';

import {Math, RAY, YEAR} from '@libraries/Math.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';
import {BaseCType} from '@test/scopes/BaseCType.t.sol';
import {ETHCType} from '@test/scopes/ETHCType.t.sol';
import {TKNCType} from '@test/scopes/TKNCType.t.sol';

uint256 constant TEST_ETH_A_SF_APR = 1.05e18; // 5%/yr

abstract contract E2ETest is BaseUser, BaseCType, Common {
  using Math for uint256;

  function test_open_safe() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));

    (uint256 _generatedDebt, uint256 _lockedCollateral) = _getSafeStatus(_cType(), address(this));
    assertEq(_generatedDebt, DEBT);
    assertEq(_lockedCollateral, COLLAT);
  }

  function test_exit_join() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));

    assertEq(systemCoin.balanceOf(address(this)), DEBT);
  }

  function test_stability_fee() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));

    uint256 _globalDebt;
    _globalDebt = safeEngine.globalDebt();
    assertEq(_globalDebt, DEBT * RAY); // RAD

    vm.warp(block.timestamp + YEAR);
    taxCollector.taxSingle(_cType());

    uint256 _globalDebtAfterTax = safeEngine.globalDebt();
    assertApproxEqAbs(_globalDebtAfterTax, Math.wmul(DEBT, TEST_ETH_A_SF_APR) * RAY, RAD_DELTA); // RAD

    uint256 _accountingEngineCoins =
      safeEngine.coinBalance(address(accountingEngine)).rmul(100 * RAY).rdiv(PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY);
    assertEq(_accountingEngineCoins, _globalDebtAfterTax - _globalDebt);
  }

  function test_liquidation() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));

    _setCollateralPrice(_cType(), TEST_ETH_PRICE_DROP);

    _liquidateSAFE(_cType(), address(this));

    assertEq(safeEngine.safes(_cType(), address(this)).lockedCollateral, 0);
    assertEq(safeEngine.safes(_cType(), address(this)).generatedDebt, 0);
  }

  function test_liquidation_by_price_drop() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));

    // NOTE: LVT for price = 1000 is 50%
    _setCollateralPrice(_cType(), 675e18); // LVT = 74,0% = 1/1.35

    vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    _liquidateSAFE(_cType(), address(this));

    _setCollateralPrice(_cType(), 674e18); // LVT = 74,1% > 1/1.35
    _liquidateSAFE(_cType(), address(this));
  }

  function test_liquidation_by_fees() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));

    _collectFees(8 * YEAR); // 1.05^8 = 148%

    vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    _liquidateSAFE(_cType(), address(this));

    _collectFees(YEAR); // 1.05^9 = 153%
    _liquidateSAFE(_cType(), address(this));
  }

  function test_collateral_auction() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(_cType(), TEST_ETH_PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

    uint256 _discount = collateralAuctionHouse[_cType()].cParams().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP);
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[_cType()].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT);

    _joinCoins(address(this), _amountToBid);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse[_cType()]));
    collateralAuctionHouse[_cType()].buyCollateral(1, _amountToBid);

    // NOTE: auctions(1) is deleted
    uint256 _amountToSell = collateralAuctionHouse[_cType()].auctions(1).amountToSell;
    assertEq(_amountToSell, 0);
  }

  function test_collateral_auction_partial() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(_cType(), TEST_ETH_PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

    uint256 _discount = collateralAuctionHouse[_cType()].cParams().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP) / 2;
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[_cType()].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT / 2);

    _joinCoins(address(this), _amountToBid);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse[_cType()]));
    collateralAuctionHouse[_cType()].buyCollateral(1, _amountToBid);

    // NOTE: auctions(1) is NOT deleted
    uint256 _amountToSell = collateralAuctionHouse[_cType()].auctions(1).amountToSell;
    assertGt(_amountToSell, 0);
  }

  function test_debt_auction() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));
    _setCollateralPrice(_cType(), TEST_ETH_PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

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
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLAT), int256(DEBT));
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

// --- Scoped test contracts ---

contract E2ETestDirectUserETH is DirectUser, ETHCType, E2ETest {}

contract E2ETestProxyUserETH is ProxyUser, ETHCType, E2ETest {}

// TODO: uncomment and fix tests
// contract E2ETestDirectUserTKN is DirectUser, TKNCType, E2ETest {}
// contract E2ETestProxyUserTKN is ProxyUser, TKNCType, E2ETest {}