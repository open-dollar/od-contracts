// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'ds-test/test.sol';

import {Coin} from '@contracts/utils/Coin.sol';
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {StabilityFeeTreasury} from '@contracts/StabilityFeeTreasury.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';

import {HOUR} from '@libraries/Math.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract Usr {
  function approveSAFEModification(address safeEngine, address lad) external {
    SAFEEngine(safeEngine).approveSAFEModification(lad);
  }

  function giveFunds(address stabilityFeeTreasury, address lad, uint256 rad) external {
    StabilityFeeTreasury(stabilityFeeTreasury).giveFunds(lad, rad);
  }

  function takeFunds(address stabilityFeeTreasury, address lad, uint256 rad) external {
    StabilityFeeTreasury(stabilityFeeTreasury).takeFunds(lad, rad);
  }

  function pullFunds(address stabilityFeeTreasury, address gal, uint256 wad) external {
    return StabilityFeeTreasury(stabilityFeeTreasury).pullFunds(gal, wad);
  }

  function approve(address systemCoin, address gal) external {
    Coin(systemCoin).approve(gal, uint256(int256(-1)));
  }
}

contract SingleStabilityFeeTreasuryTest is DSTest {
  Hevm hevm;

  SAFEEngine safeEngine;
  StabilityFeeTreasury stabilityFeeTreasury;

  Coin systemCoin;
  CoinJoin systemCoinA;

  Usr usr;

  address alice = address(0x1);
  address bob = address(0x2);

  uint256 constant HUNDRED = 10 ** 2;
  uint256 constant RAY = 10 ** 27;

  function ray(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 9;
  }

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * RAY;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    usr = new Usr();

    safeEngine = new SAFEEngine();
    systemCoin = new Coin('Coin', 'COIN', 99);
    systemCoinA = new CoinJoin(address(safeEngine), address(systemCoin));
    stabilityFeeTreasury = new StabilityFeeTreasury(address(safeEngine), alice, address(systemCoinA));

    systemCoin.addAuthorization(address(systemCoinA));
    stabilityFeeTreasury.addAuthorization(address(systemCoinA));

    safeEngine.createUnbackedDebt(bob, address(stabilityFeeTreasury), rad(200 ether));
    safeEngine.createUnbackedDebt(bob, address(this), rad(100 ether));

    safeEngine.approveSAFEModification(address(systemCoinA));
    systemCoinA.exit(address(this), 100 ether);

    usr.approveSAFEModification(address(safeEngine), address(stabilityFeeTreasury));
  }

  function test_setup() public {
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _params = stabilityFeeTreasury.params();

    assertEq(_params.surplusTransferDelay, 0);
    assertEq(address(stabilityFeeTreasury.safeEngine()), address(safeEngine));
    assertEq(address(stabilityFeeTreasury.extraSurplusReceiver()), alice);
    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
    assertEq(_params.expensesMultiplier, HUNDRED);
    assertEq(systemCoin.balanceOf(address(this)), 100 ether);
    assertEq(safeEngine.coinBalance(address(alice)), 0);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(200 ether));
  }

  function test_modify_extra_surplus_receiver() public {
    stabilityFeeTreasury.modifyParameters('extraSurplusReceiver', abi.encode(bob));
    assertEq(stabilityFeeTreasury.extraSurplusReceiver(), bob);
  }

  function test_modify_params() public {
    stabilityFeeTreasury.modifyParameters('expensesMultiplier', abi.encode(5 * HUNDRED));
    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(rad(50 ether)));
    stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(10 minutes));
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _params = stabilityFeeTreasury.params();
    assertEq(_params.expensesMultiplier, 5 * HUNDRED);
    assertEq(_params.treasuryCapacity, rad(50 ether));
    assertEq(_params.surplusTransferDelay, 10 minutes);
  }

  function test_transferSurplusFunds_no_expenses_no_minimumFundsRequired() public {
    hevm.warp(block.timestamp + 1 seconds);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(stabilityFeeTreasury.accumulatorTag(), 0);
    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(alice)), rad(200 ether));
  }

  function test_transferSurplusFunds_no_expenses_with_minimumFundsRequired() public {
    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(rad(50 ether)));
    stabilityFeeTreasury.modifyParameters('minimumFundsRequired', abi.encode(rad(50 ether)));
    hevm.warp(block.timestamp + 1 seconds);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(stabilityFeeTreasury.accumulatorTag(), 0);
    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(50 ether));
    assertEq(safeEngine.coinBalance(address(alice)), rad(150 ether));
  }

  function test_transferSurplusFunds_no_expenses_both_internal_and_external_coins() public {
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _params = stabilityFeeTreasury.params();
    assertEq(_params.treasuryCapacity, 0);
    assertEq(_params.expensesMultiplier, HUNDRED);
    assertEq(stabilityFeeTreasury.expensesAccumulator(), 0);
    assertEq(_params.minFundsRequired, 0);
    systemCoin.transfer(address(stabilityFeeTreasury), 1 ether);
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 1 ether);
    hevm.warp(block.timestamp + 1 seconds);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(alice)), rad(201 ether));
  }

  function test_transferSurplusFunds_no_expenses_with_minimumFundsRequired_both_internal_and_external_coins() public {
    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(rad(50 ether)));
    stabilityFeeTreasury.modifyParameters('minimumFundsRequired', abi.encode(rad(50 ether)));
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _params = stabilityFeeTreasury.params();
    assertEq(_params.treasuryCapacity, rad(50 ether));
    assertEq(_params.expensesMultiplier, HUNDRED);
    assertEq(stabilityFeeTreasury.expensesAccumulator(), 0);
    assertEq(_params.minFundsRequired, rad(50 ether));
    systemCoin.transfer(address(stabilityFeeTreasury), 1 ether);
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 1 ether);
    hevm.warp(block.timestamp + 1 seconds);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(50 ether));
    assertEq(safeEngine.coinBalance(address(alice)), rad(151 ether));
  }

  function test_setTotalAllowance() public {
    stabilityFeeTreasury.setTotalAllowance(alice, 10 ether);
    (uint256 total, uint256 perHour) = stabilityFeeTreasury.allowance(alice);
    assertEq(total, 10 ether);
    assertEq(perHour, 0);
  }

  function test_setPerHourAllowance() public {
    stabilityFeeTreasury.setPerHourAllowance(alice, 1 ether);
    (uint256 total, uint256 perHour) = stabilityFeeTreasury.allowance(alice);
    assertEq(total, 0);
    assertEq(perHour, 1 ether);
  }

  function testFail_give_non_relied() public {
    usr.giveFunds(address(stabilityFeeTreasury), address(usr), rad(5 ether));
  }

  function testFail_take_non_relied() public {
    stabilityFeeTreasury.giveFunds(address(usr), rad(5 ether));
    usr.takeFunds(address(stabilityFeeTreasury), address(usr), rad(2 ether));
  }

  function test_give_take() public {
    assertEq(safeEngine.coinBalance(address(usr)), 0);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(200 ether));
    stabilityFeeTreasury.giveFunds(address(usr), rad(5 ether));
    assertEq(safeEngine.coinBalance(address(usr)), rad(5 ether));
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(195 ether));
    stabilityFeeTreasury.takeFunds(address(usr), rad(2 ether));
    assertEq(safeEngine.coinBalance(address(usr)), rad(3 ether));
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(197 ether));
    assertEq(stabilityFeeTreasury.expensesAccumulator(), rad(5 ether));
  }

  function testFail_give_more_debt_than_coin() public {
    safeEngine.createUnbackedDebt(
      address(stabilityFeeTreasury), address(this), safeEngine.coinBalance(address(stabilityFeeTreasury)) + 1
    );

    assertEq(safeEngine.coinBalance(address(usr)), 0);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(200 ether));
    stabilityFeeTreasury.giveFunds(address(usr), rad(5 ether));
  }

  function testFail_give_more_debt_than_coin_after_join() public {
    systemCoin.transfer(address(stabilityFeeTreasury), 100 ether);
    safeEngine.createUnbackedDebt(
      address(stabilityFeeTreasury),
      address(this),
      safeEngine.coinBalance(address(stabilityFeeTreasury)) + rad(100 ether) + 1
    );

    assertEq(safeEngine.coinBalance(address(usr)), 0);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(200 ether));
    stabilityFeeTreasury.giveFunds(address(usr), rad(5 ether));
  }

  function testFail_pull_above_setTotalAllowance() public {
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), rad(11 ether));
  }

  function testFail_pull_null_tkn_amount() public {
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 0);
  }

  function testFail_pull_null_account() public {
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(0), rad(1 ether));
  }

  function testFail_pull_random_token() public {
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), rad(1 ether));
  }

  function test_pull_funds_no_block_limit() public {
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 1 ether);
    (uint256 total,) = stabilityFeeTreasury.allowance(address(usr));
    assertEq(total, rad(9 ether));
    assertEq(systemCoin.balanceOf(address(usr)), 0);
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(usr)), rad(1 ether));
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(199 ether));
    assertEq(stabilityFeeTreasury.expensesAccumulator(), rad(1 ether));
  }

  function test_pull_funds_to_treasury_no_block_limit() public {
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(200 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(stabilityFeeTreasury), 1 ether);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(200 ether));
  }

  function test_pull_funds_under_block_limit() public {
    stabilityFeeTreasury.setPerHourAllowance(address(usr), rad(1 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 0.9 ether);
    (uint256 total,) = stabilityFeeTreasury.allowance(address(usr));
    assertEq(total, rad(9.1 ether));
    assertEq(stabilityFeeTreasury.pulledPerHour(address(usr), block.timestamp / HOUR), rad(0.9 ether));
    assertEq(systemCoin.balanceOf(address(usr)), 0);
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(usr)), rad(0.9 ether));
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(199.1 ether));
    assertEq(stabilityFeeTreasury.expensesAccumulator(), rad(0.9 ether));
  }

  function testFail_pull_funds_when_funds_below_pull_threshold() public {
    stabilityFeeTreasury.modifyParameters(
      'pullFundsMinThreshold', abi.encode(safeEngine.coinBalance(address(stabilityFeeTreasury)) + 1)
    );
    stabilityFeeTreasury.setPerHourAllowance(address(usr), rad(1 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 0.9 ether);
  }

  function testFail_pull_funds_more_debt_than_coin() public {
    stabilityFeeTreasury.setPerHourAllowance(address(usr), rad(1 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    safeEngine.createUnbackedDebt(
      address(stabilityFeeTreasury), address(this), safeEngine.coinBalance(address(stabilityFeeTreasury)) + 1
    );
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 0.9 ether);
  }

  function testFail_pull_funds_more_debt_than_coin_post_join() public {
    systemCoin.transfer(address(stabilityFeeTreasury), 100 ether);
    stabilityFeeTreasury.setPerHourAllowance(address(usr), rad(1 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    safeEngine.createUnbackedDebt(
      address(stabilityFeeTreasury),
      address(this),
      safeEngine.coinBalance(address(stabilityFeeTreasury)) + rad(100 ether) + 1
    );
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 0.9 ether);
  }

  function test_pull_funds_less_debt_than_coin() public {
    stabilityFeeTreasury.setPerHourAllowance(address(usr), rad(1 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    safeEngine.createUnbackedDebt(
      address(stabilityFeeTreasury), address(this), safeEngine.coinBalance(address(stabilityFeeTreasury)) - rad(1 ether)
    );
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 0.9 ether);

    (uint256 total,) = stabilityFeeTreasury.allowance(address(usr));
    assertEq(total, rad(9.1 ether));
    assertEq(stabilityFeeTreasury.pulledPerHour(address(usr), block.timestamp / HOUR), rad(0.9 ether));
    assertEq(systemCoin.balanceOf(address(usr)), 0);
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(usr)), rad(0.9 ether));
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(0.1 ether));
  }

  function test_less_debt_than_coin_post_join() public {
    systemCoin.transfer(address(stabilityFeeTreasury), 100 ether);
    stabilityFeeTreasury.setPerHourAllowance(address(usr), rad(1 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    safeEngine.createUnbackedDebt(
      address(stabilityFeeTreasury), address(this), safeEngine.coinBalance(address(stabilityFeeTreasury)) - rad(1 ether)
    );
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 0.9 ether);

    (uint256 total,) = stabilityFeeTreasury.allowance(address(usr));
    assertEq(total, rad(9.1 ether));
    assertEq(stabilityFeeTreasury.pulledPerHour(address(usr), block.timestamp / HOUR), rad(0.9 ether));
    assertEq(systemCoin.balanceOf(address(usr)), 0);
    assertEq(systemCoin.balanceOf(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(usr)), rad(0.9 ether));
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(100.1 ether));
  }

  function testFail_pull_funds_above_block_limit() public {
    stabilityFeeTreasury.setPerHourAllowance(address(usr), rad(1 ether));
    stabilityFeeTreasury.setTotalAllowance(address(usr), rad(10 ether));
    usr.pullFunds(address(stabilityFeeTreasury), address(usr), 10 ether);
  }

  function testFail_transferSurplusFunds_before_surplusDelay() public {
    stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(10 minutes));
    hevm.warp(block.timestamp + 9 minutes);
    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_transferSurplusFunds_after_expenses() public {
    address charlie = address(0x12345);
    stabilityFeeTreasury.modifyParameters('extraSurplusReceiver', abi.encode(charlie));

    stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(10 minutes));
    stabilityFeeTreasury.giveFunds(alice, rad(40 ether));
    hevm.warp(block.timestamp + 10 minutes);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(alice)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(charlie)), rad(120 ether));
    hevm.warp(block.timestamp + 10 minutes);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), 0);
    assertEq(safeEngine.coinBalance(address(alice)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(charlie)), rad(160 ether));
  }

  function test_transferSurplusFunds_after_expenses_with_treasuryCapacity_and_minimumFundsRequired() public {
    address charlie = address(0x12345);
    stabilityFeeTreasury.modifyParameters('extraSurplusReceiver', abi.encode(charlie));

    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(rad(30 ether)));
    stabilityFeeTreasury.modifyParameters('minimumFundsRequired', abi.encode(rad(10 ether)));
    stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(10 minutes));
    stabilityFeeTreasury.giveFunds(alice, rad(40 ether));
    hevm.warp(block.timestamp + 10 minutes);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(alice)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(charlie)), rad(120 ether));
    hevm.warp(block.timestamp + 10 minutes);
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(10 ether));
    assertEq(safeEngine.coinBalance(address(alice)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(charlie)), rad(150 ether));
  }

  function testFail_transferSurplusFunds_more_debt_than_coin() public {
    address charlie = address(0x12345);
    stabilityFeeTreasury.modifyParameters('extraSurplusReceiver', abi.encode(charlie));

    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(rad(30 ether)));
    stabilityFeeTreasury.modifyParameters('minimumFundsRequired', abi.encode(rad(10 ether)));
    stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(10 minutes));

    stabilityFeeTreasury.giveFunds(alice, rad(40 ether));
    safeEngine.createUnbackedDebt(address(stabilityFeeTreasury), address(this), rad(161 ether));

    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(160 ether));
    assertEq(safeEngine.debtBalance(address(stabilityFeeTreasury)), rad(161 ether));

    hevm.warp(block.timestamp + 10 minutes);
    stabilityFeeTreasury.transferSurplusFunds();
  }

  function test_transferSurplusFunds_less_debt_than_coin() public {
    address charlie = address(0x12345);
    stabilityFeeTreasury.modifyParameters('extraSurplusReceiver', abi.encode(charlie));

    stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(rad(30 ether)));
    stabilityFeeTreasury.modifyParameters('minimumFundsRequired', abi.encode(rad(10 ether)));
    stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(10 minutes));

    stabilityFeeTreasury.giveFunds(alice, rad(40 ether));
    safeEngine.createUnbackedDebt(address(stabilityFeeTreasury), address(this), rad(50 ether));

    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(160 ether));
    assertEq(safeEngine.debtBalance(address(stabilityFeeTreasury)), rad(50 ether));

    hevm.warp(block.timestamp + 10 minutes);
    stabilityFeeTreasury.transferSurplusFunds();

    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(alice)), rad(40 ether));
    assertEq(safeEngine.coinBalance(address(charlie)), rad(70 ether));
  }
}
