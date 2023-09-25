// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Common, RAD_DELTA} from './Common.t.sol';

import {ILiquidationEngine, IDebtAuctionHouse, ISurplusAuctionHouse} from '@script/Contracts.s.sol';
import {
  INITIAL_DEBT_AUCTION_MINTED_TOKENS,
  ONE_HUNDRED_COINS,
  PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY,
  SURPLUS_AUCTION_BID_RECEIVER
} from '@test/e2e/TestParams.t.sol';

import {Math, RAY, WAD, YEAR} from '@libraries/Math.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';
import {Base_CType} from '@test/scopes/Base_CType.t.sol';
import {ETH_CType} from '@test/scopes/ETH_CType.t.sol';
import {TKN_CType} from '@test/scopes/TKN_CType.t.sol';
import {TKN_8D_CType} from '@test/scopes/TKN_8D_CType.t.sol';

uint256 constant COLLATERAL_AMOUNT = 1e18; // 1
uint256 constant DEBT_AMOUNT = 500e18; // 500 HAI
uint256 constant STABILITY_FEE = RAY + 1.54713e18; // 5%/yr
uint256 constant STABILITY_FEE_APR = 1.05e18; // 5%/yr
uint256 constant LIQUIDATION_C_RATIO = 1.35e27; // 135%
uint256 constant INITIAL_PRICE = 1000e18; // $1000
uint256 constant PRICE_DROP = 100e18; // $100
uint256 constant LIQUIDATION_PENALTY = 1.1e18; // 10%

abstract contract E2ETest is BaseUser, Base_CType, Common {
  using Math for uint256;

  function setUp() public override {
    super.setUp();

    vm.startPrank(deployer); // no governor on test deployment
    taxCollector.modifyParameters('globalStabilityFee', abi.encode(STABILITY_FEE));
    taxCollector.modifyParameters(_cType(), 'stabilityFee', abi.encode(RAY));
    oracleRelayer.modifyParameters(_cType(), 'liquidationCRatio', abi.encode(LIQUIDATION_C_RATIO));
    vm.stopPrank();

    _setCollateralPrice(_cType(), INITIAL_PRICE);
    taxCollector.taxSingle(_cType());
  }

  function test_open_safe() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    (uint256 _generatedDebt, uint256 _lockedCollateral) = _getSafeStatus(_cType(), address(this));
    assertEq(_generatedDebt, DEBT_AMOUNT);
    assertEq(_lockedCollateral, COLLATERAL_AMOUNT);
  }

  function test_exit_collateral() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    _repayDebtAndExit(address(this), address(collateralJoin[_cType()]), COLLATERAL_AMOUNT, DEBT_AMOUNT);

    uint256 _decimals = collateral[_cType()].decimals();
    uint256 _wei = COLLATERAL_AMOUNT / 10 ** (18 - _decimals);
    assertEq(collateralJoin[_cType()].collateral().balanceOf(address(this)), _wei);
  }

  function test_exit_join() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    assertEq(systemCoin.balanceOf(address(this)), DEBT_AMOUNT);
  }

  function test_stability_fee() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    uint256 _globalDebt;
    _globalDebt = safeEngine.globalDebt();
    assertEq(_globalDebt, DEBT_AMOUNT * RAY); // RAD

    vm.warp(block.timestamp + YEAR);
    taxCollector.taxSingle(_cType());

    uint256 _globalDebtAfterTax = safeEngine.globalDebt();
    assertApproxEqAbs(_globalDebtAfterTax, Math.wmul(DEBT_AMOUNT, STABILITY_FEE_APR) * RAY, RAD_DELTA); // RAD

    uint256 _accountingEngineCoins =
      safeEngine.coinBalance(address(accountingEngine)).rmul(100 * RAY).rdiv(PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY);
    assertEq(_accountingEngineCoins, _globalDebtAfterTax - _globalDebt);
  }

  function test_liquidation() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    _setCollateralPrice(_cType(), PRICE_DROP);

    _liquidateSAFE(_cType(), address(this));

    assertEq(safeEngine.safes(_cType(), address(this)).lockedCollateral, 0);
    assertEq(safeEngine.safes(_cType(), address(this)).generatedDebt, 0);
  }

  function test_liquidation_by_price_drop() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    // NOTE: LVT for price = 1000 is 50%
    _setCollateralPrice(_cType(), 675e18); // LVT = 74,0% = 1/1.35

    vm.expectRevert(ILiquidationEngine.LiqEng_SAFENotUnsafe.selector);
    _liquidateSAFE(_cType(), address(this));

    _setCollateralPrice(_cType(), 674e18); // LVT = 74,1% > 1/1.35
    _liquidateSAFE(_cType(), address(this));
  }

  function test_liquidation_by_fees() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));

    _collectFees(_cType(), 8 * YEAR); // 1.05^8 = 148%

    vm.expectRevert(ILiquidationEngine.LiqEng_SAFENotUnsafe.selector);
    _liquidateSAFE(_cType(), address(this));

    _collectFees(_cType(), YEAR); // 1.05^9 = 153%
    _liquidateSAFE(_cType(), address(this));
  }

  function test_collateral_auction() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = collateral[_cType()].balanceOf(address(this));
    _setCollateralPrice(_cType(), PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

    uint256 _discount = collateralAuctionHouse[_cType()].params().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLATERAL_AMOUNT, _discount), PRICE_DROP);
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[_cType()].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLATERAL_AMOUNT);

    _joinCoins(address(this), _amountToBid);

    _buyCollateral(address(this), address(collateralAuctionHouse[_cType()]), 1, _expectedCollateral, _amountToBid);

    uint256 _decimals = collateral[_cType()].decimals();
    uint256 _collateralWei = _expectedCollateral / 10 ** (18 - _decimals);
    assertEq(collateral[_cType()].balanceOf(address(this)) - _initialBalance, _collateralWei);

    // NOTE: auctions(1) is deleted
    uint256 _amountToSell = collateralAuctionHouse[_cType()].auctions(1).amountToSell;
    assertEq(_amountToSell, 0);
  }

  function test_collateral_auction_partial() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = collateral[_cType()].balanceOf(address(this));
    _setCollateralPrice(_cType(), PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

    uint256 _discount = collateralAuctionHouse[_cType()].params().minDiscount;
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLATERAL_AMOUNT, _discount), PRICE_DROP) / 2;
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse[_cType()].getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLATERAL_AMOUNT / 2);

    _joinCoins(address(this), _amountToBid);

    _buyCollateral(address(this), address(collateralAuctionHouse[_cType()]), 1, _expectedCollateral, _amountToBid);

    uint256 _decimals = collateral[_cType()].decimals();
    uint256 _collateralWei = _expectedCollateral / 10 ** (18 - _decimals);
    assertEq(collateral[_cType()].balanceOf(address(this)) - _initialBalance, _collateralWei);

    // NOTE: auctions(1) is NOT deleted
    uint256 _amountToSell = collateralAuctionHouse[_cType()].auctions(1).amountToSell;
    assertGt(_amountToSell, 0);
  }

  function test_debt_auction() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialCoinBalance = systemCoin.balanceOf(address(this));
    _setCollateralPrice(_cType(), PRICE_DROP);
    _liquidateSAFE(_cType(), address(this));

    accountingEngine.popDebtFromQueue(block.timestamp);
    accountingEngine.auctionDebt();

    IDebtAuctionHouse.Auction memory _auction = debtAuctionHouse.auctions(1);
    assertEq(_auction.bidAmount, ONE_HUNDRED_COINS);
    assertEq(_auction.amountToSell, INITIAL_DEBT_AUCTION_MINTED_TOKENS);
    assertEq(_auction.highBidder, address(accountingEngine));

    uint256 _bidDecrease = debtAuctionHouse.params().bidDecrease;
    uint256 _tokenAmount = Math.wdiv(INITIAL_DEBT_AUCTION_MINTED_TOKENS, _bidDecrease);

    _buyProtocolToken(address(this), 1, _tokenAmount, _auction.bidAmount);

    _auction = debtAuctionHouse.auctions(1);
    assertEq(_auction.bidAmount, ONE_HUNDRED_COINS);
    assertEq(_auction.amountToSell, _tokenAmount);

    vm.warp(_auction.auctionDeadline);
    _settleDebtAuction(address(this), 1);

    assertEq(_initialCoinBalance - systemCoin.balanceOf(address(this)), ONE_HUNDRED_COINS / RAY);
    assertEq(protocolToken.balanceOf(address(this)), _tokenAmount);
  }

  function test_surplus_auction() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    uint256 INITIAL_BID = 1e18;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), INITIAL_BID);

    // generate surplus
    _collectFees(_cType(), 10 * YEAR);

    uint256 _auctionId = accountingEngine.auctionSurplus();
    _increaseBidSize(address(this), _auctionId, INITIAL_BID);

    ISurplusAuctionHouse.Auction memory _auction = surplusAuctionHouse.auctions(_auctionId);
    assertEq(_auction.bidAmount, INITIAL_BID);

    vm.warp(_auction.auctionDeadline);

    assertEq(protocolToken.totalSupply(), INITIAL_BID);
    _settleSurplusAuction(address(this), _auctionId);
    assertEq(protocolToken.totalSupply(), INITIAL_BID / 2); // 50% of the bid is burned
    assertEq(protocolToken.balanceOf(SURPLUS_AUCTION_BID_RECEIVER), INITIAL_BID / 2); // 50% is sent to the receiver
    assertEq(protocolToken.balanceOf(address(this)), 0);
    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, _auction.amountToSell / RAY);
  }

  function test_surplus_auction_and_bid() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    uint256 INITIAL_BID = 1e18;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), INITIAL_BID);

    // generate surplus
    _collectFees(_cType(), 10 * YEAR);

    uint256 _auctionId = accountingEngine.auctionSurplus();
    _increaseBidSize(address(this), _auctionId, INITIAL_BID);

    ISurplusAuctionHouse.Auction memory _auction = surplusAuctionHouse.auctions(_auctionId);
    assertEq(_auction.bidAmount, INITIAL_BID);

    vm.warp(_auction.auctionDeadline);

    assertEq(protocolToken.totalSupply(), INITIAL_BID);
    surplusAuctionHouse.settleAuction(_auctionId);
    _collectSystemCoins(address(this));
    assertEq(protocolToken.totalSupply(), INITIAL_BID / 2); // 50% of the bid is burned
    assertEq(protocolToken.balanceOf(SURPLUS_AUCTION_BID_RECEIVER), INITIAL_BID / 2); // 50% is sent to the receiver
    assertEq(protocolToken.balanceOf(address(this)), 0);
    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, _auction.amountToSell / RAY);
  }

  function test_surplus_auction_and_multi_bid() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    uint256 INITIAL_BID = 1e18;
    address other_user = label('other_user');

    uint256 _bidIncrease = surplusAuctionHouse.params().bidIncrease;
    uint256 _secondBid = INITIAL_BID * _bidIncrease / WAD;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(other_user, INITIAL_BID);
    vm.prank(deployer);
    protocolToken.mint(address(this), _secondBid);

    // generate surplus
    _collectFees(_cType(), 10 * YEAR);

    uint256 _auctionId = accountingEngine.auctionSurplus();
    _increaseBidSize(other_user, _auctionId, INITIAL_BID);
    _increaseBidSize(address(this), _auctionId, _secondBid);

    ISurplusAuctionHouse.Auction memory _auction = surplusAuctionHouse.auctions(_auctionId);
    assertEq(_auction.bidAmount, _secondBid);

    vm.warp(_auction.auctionDeadline);

    assertEq(protocolToken.totalSupply(), INITIAL_BID + _secondBid);
    surplusAuctionHouse.settleAuction(_auctionId);
    _collectSystemCoins(address(this));
    // 50% of the winning bid is burned
    assertEq(protocolToken.totalSupply(), INITIAL_BID + (_secondBid / 2));
    // 50% of the winning bid is sent to the receiver
    assertEq(protocolToken.balanceOf(SURPLUS_AUCTION_BID_RECEIVER), _secondBid / 2);
    assertEq(protocolToken.balanceOf(address(this)), 0);
    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, _auction.amountToSell / RAY);
  }

  function test_surplus_auction_and_rebid() public {
    _generateDebt(address(this), address(collateralJoin[_cType()]), int256(COLLATERAL_AMOUNT), int256(DEBT_AMOUNT));
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    uint256 INITIAL_BID = 1e18;

    uint256 _bidIncrease = surplusAuctionHouse.params().bidIncrease;
    uint256 _secondBid = INITIAL_BID * _bidIncrease / WAD;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), _secondBid);

    // generate surplus
    _collectFees(_cType(), 10 * YEAR);

    uint256 _auctionId = accountingEngine.auctionSurplus();
    _increaseBidSize(address(this), _auctionId, INITIAL_BID);
    _increaseBidSize(address(this), _auctionId, _secondBid);

    ISurplusAuctionHouse.Auction memory _auction = surplusAuctionHouse.auctions(_auctionId);
    assertEq(_auction.bidAmount, _secondBid);

    vm.warp(_auction.auctionDeadline);

    assertEq(protocolToken.totalSupply(), _secondBid);
    surplusAuctionHouse.settleAuction(_auctionId);
    _collectSystemCoins(address(this));
    // 50% of the winning bid is burned
    assertEq(protocolToken.totalSupply(), _secondBid / 2);
    // 50% of the winning bid is sent to the receiver
    assertEq(protocolToken.balanceOf(SURPLUS_AUCTION_BID_RECEIVER), _secondBid / 2);
    assertEq(protocolToken.balanceOf(address(this)), 0);
    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, _auction.amountToSell / RAY);
  }
}

// --- Scoped test contracts ---

// NOTE: ETH tests not implemented (fails on exit bc of fallback)
// contract E2ETestDirectUserETH is DirectUser, ETH_CType, E2ETest {}

// contract E2ETestProxyUserETH is ProxyUser, ETH_CType, E2ETest {}

contract E2ETestDirectUserTKN is DirectUser, TKN_CType, E2ETest {}

contract E2ETestProxyUserTKN is ProxyUser, TKN_CType, E2ETest {}

contract E2ETestDirectUserTKN8D is DirectUser, TKN_8D_CType, E2ETest {}

contract E2ETestProxyUserTKN8D is ProxyUser, TKN_8D_CType, E2ETest {}
