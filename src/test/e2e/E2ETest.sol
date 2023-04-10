// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PRBTest} from 'prb-test/PRBTest.sol';
import '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';
import {Contracts} from '@script/Contracts.s.sol';
import {Math} from '@libraries/Math.sol';

uint256 constant YEAR = 365 days;
uint256 constant RAY = 1e27;
uint256 constant RAD_DELTA = 0.0001e45;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%

contract E2ETest is PRBTest, Contracts {
  Deploy deployment;
  address deployer;
  uint256 auctionId;

  function setUp() public {
    deployment = new Deploy();
    deployment.run();
    deployer = deployment.deployer();

    safeEngine = deployment.safeEngine();
    accountingEngine = deployment.accountingEngine();
    taxCollector = deployment.taxCollector();
    debtAuctionHouse = deployment.debtAuctionHouse();
    surplusAuctionHouse = deployment.surplusAuctionHouse();
    liquidationEngine = deployment.liquidationEngine();
    oracleRelayer = deployment.oracleRelayer();
    coinJoin = deployment.coinJoin();
    coin = deployment.coin();
    protocolToken = deployment.protocolToken();

    ethJoin = deployment.ethJoin();
    ethOracle = deployment.ethOracle();
    collateralAuctionHouse = deployment.ethCollateralAuctionHouse();
  }

  function test_open_safe() public {
    ethJoin.join{value: 100e18}(address(this));
    safeEngine.approveSAFEModification(address(ethJoin));
    safeEngine.approveSAFEModification(address(coinJoin));

    safeEngine.modifySAFECollateralization({
      _collateralType: ETH_A,
      _safe: address(this),
      _collateralSource: address(this),
      _debtDestination: address(this),
      _deltaCollateral: int256(COLLAT),
      _deltaDebt: int256(DEBT)
    });

    (uint256 _lockedCollateral, uint256 _generatedDebt) = safeEngine.safes(ETH_A, address(this));
    assertEq(_generatedDebt, DEBT);
    assertEq(_lockedCollateral, COLLAT);
  }

  function test_exit_join() public {
    test_open_safe();

    coinJoin.exit(address(this), DEBT);
    assertEq(coin.balanceOf(address(this)), DEBT);
  }

  function test_stability_fee() public {
    test_open_safe();

    uint256 _globalDebt;
    _globalDebt = safeEngine.globalDebt();
    assertEq(_globalDebt, DEBT * RAY); // RAD

    vm.warp(block.timestamp + YEAR);
    taxCollector.taxSingle(ETH_A);

    uint256 _globalDebtAfterTax = safeEngine.globalDebt();
    assertAlmostEq(_globalDebtAfterTax, Math.wmul(DEBT, TEST_ETH_A_SF_APR) * RAY, RAD_DELTA); // RAD

    uint256 _accountingEngineCoins = safeEngine.coinBalance(address(accountingEngine));
    assertEq(_accountingEngineCoins, _globalDebtAfterTax - _globalDebt);
  }

  function test_liquidation() public {
    test_open_safe();

    ethOracle.setPriceAndValidity(TEST_ETH_PRICE_DROP, true);
    oracleRelayer.updateCollateralPrice(ETH_A);

    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    (uint256 _lockedCollateral, uint256 _generatedDebt) = safeEngine.safes(ETH_A, address(this));
    assertEq(_lockedCollateral, 0);
    assertEq(_generatedDebt, 0);
  }

  function test_liquidation_by_price_drop() public {
    test_open_safe();

    // NOTE: LVT for price = 1000 is 50%
    ethOracle.setPriceAndValidity(675e18, true); // LVT = 74,0% = 1/1.35
    oracleRelayer.updateCollateralPrice(ETH_A);

    vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    ethOracle.setPriceAndValidity(674e18, true); // LVT = 74,1% > 1/1.35
    oracleRelayer.updateCollateralPrice(ETH_A);

    liquidationEngine.liquidateSAFE(ETH_A, address(this));
  }

  function test_liquidation_by_fees() public {
    test_open_safe();

    // LVT = 50% => 74% = 148%
    vm.warp(block.timestamp + 8 * YEAR); // 1.05^8 = 148%
    taxCollector.taxSingle(ETH_A);

    vm.expectRevert('LiquidationEngine/safe-not-unsafe');
    liquidationEngine.liquidateSAFE(ETH_A, address(this));

    vm.warp(block.timestamp + YEAR); // 1.05^9 = 153%
    taxCollector.taxSingle(ETH_A);
    liquidationEngine.liquidateSAFE(ETH_A, address(this));
  }

  function test_collateral_auction() public {
    test_liquidation(); // price is 100=1

    uint256 _discount = collateralAuctionHouse.minDiscount();
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP);
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse.getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse));
    collateralAuctionHouse.buyCollateral(1, _amountToBid);

    // NOTE: bids(1) is deleted
    (uint256 _amountToSell,,,,,,,,) = collateralAuctionHouse.bids(1);
    assertEq(_amountToSell, 0);
  }

  function test_collateral_auction_partial() public {
    test_liquidation(); // price is 100=1

    uint256 _discount = collateralAuctionHouse.minDiscount();
    uint256 _amountToBid = Math.wmul(Math.wmul(COLLAT, _discount), TEST_ETH_PRICE_DROP) / 2;
    // NOTE: getExpectedCollateralBought doesn't have a previous reference (lastReadRedemptionPrice)
    (uint256 _expectedCollateral,) = collateralAuctionHouse.getCollateralBought(1, _amountToBid);
    assertEq(_expectedCollateral, COLLAT / 2);

    safeEngine.approveSAFEModification(address(collateralAuctionHouse));
    collateralAuctionHouse.buyCollateral(1, _amountToBid);

    // NOTE: bids(1) is NOT deleted
    (uint256 _amountToSell,,,,,,,,) = collateralAuctionHouse.bids(1);
    assertGt(_amountToSell, 0);
  }

  function test_debt_auction() public {
    test_liquidation();

    accountingEngine.popDebtFromQueue(block.timestamp);
    accountingEngine.auctionDebt();

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder,, uint48 _auctionDeadline) =
      debtAuctionHouse.bids(1);
    assertEq(_bidAmount, BID_AUCTION_SIZE);
    assertEq(_amountToSell, INITIAL_DEBT_AUCTION_MINTED_TOKENS);
    assertEq(_highBidder, address(accountingEngine));

    uint256 _deltaCoinBalance = safeEngine.coinBalance(address(this));
    uint256 _bidDecrease = debtAuctionHouse.bidDecrease();
    uint256 _tokenAmount = Math.wdiv(INITIAL_DEBT_AUCTION_MINTED_TOKENS, _bidDecrease);

    safeEngine.approveSAFEModification(address(debtAuctionHouse));
    debtAuctionHouse.decreaseSoldAmount(1, _tokenAmount, BID_AUCTION_SIZE);

    (_bidAmount, _amountToSell, _highBidder,,) = debtAuctionHouse.bids(1);
    assertEq(_bidAmount, BID_AUCTION_SIZE);
    assertEq(_amountToSell, _tokenAmount);
    assertEq(_highBidder, address(this));

    vm.warp(_auctionDeadline);
    debtAuctionHouse.settleAuction(1);

    _deltaCoinBalance -= safeEngine.coinBalance(address(this));
    assertEq(_deltaCoinBalance, BID_AUCTION_SIZE);
    assertEq(protocolToken.balanceOf(address(this)), _tokenAmount);
  }

  function test_surplus_auction() public {
    test_open_safe();
    uint256 INITIAL_BID = 1e18;

    // mint protocol tokens to bid with
    vm.prank(deployer);
    protocolToken.mint(address(this), INITIAL_BID);

    // generate surplus
    vm.warp(block.timestamp + 10 * YEAR);
    taxCollector.taxSingle(ETH_A);

    accountingEngine.auctionSurplus();

    uint256 _delay = surplusAuctionHouse.totalAuctionLength();
    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder,, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(1);
    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, SURPLUS_AUCTION_SIZE);
    assertEq(_highBidder, address(accountingEngine));
    assertEq(_auctionDeadline, block.timestamp + _delay);

    protocolToken.approve(address(surplusAuctionHouse), INITIAL_BID);
    surplusAuctionHouse.increaseBidSize(1, SURPLUS_AUCTION_SIZE, INITIAL_BID);

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
