// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, COLLAT, DEBT, TKN} from './Common.t.sol';
import {JOB_REWARD} from '@script/Params.s.sol';

import {AccountingJob, IAccountingJob} from '@contracts/jobs/AccountingJob.sol';
import {LiquidationJob, ILiquidationJob} from '@contracts/jobs/LiquidationJob.sol';
import {OracleJob, IOracleJob} from '@contracts/jobs/OracleJob.sol';

import {RAY, YEAR} from '@libraries/Math.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';

abstract contract E2EJobsTest is BaseUser, Common {
  address safeHandler;

  function setUp() public override {
    super.setUp();

    // Opening a SAFE to generate stability fees
    address alice = address(0x420);

    _generateDebt(alice, address(collateralJoin[TKN]), int256(1000 * COLLAT), int256(DEBT));
    safeHandler = _getSafeHandler(TKN, alice);

    // Collecting fees for stabilityFeeTreasury
    _collectFees(TKN, YEAR * 10);
  }

  function test_work_pop_debt_from_queue(uint256 _debtBlock) public {
    vm.assume(_debtBlock != 0);
    vm.prank(deployer);
    accountingEngine.pushDebtToQueue(_debtBlock);
    uint256 _debtTimestamp = block.timestamp;
    vm.warp(_debtTimestamp + accountingEngine.params().popDebtDelay);

    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    _workPopDebtFromQueue(address(this), _debtTimestamp);

    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, JOB_REWARD);
  }

  function test_work_auction_debt() public {
    liquidationEngine.liquidateSAFE(TKN, safeHandler);
    accountingEngine.popDebtFromQueue(block.timestamp);

    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    _workAuctionDebt(address(this));

    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, JOB_REWARD);
  }

  function test_work_auction_surplus() public {
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    _workAuctionSurplus(address(this));

    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, JOB_REWARD);
  }

  function test_work_transfer_extra_surplus() public {
    vm.startPrank(deployer);
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(address(0x420)));
    vm.stopPrank();

    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    _workTransferExtraSurplus(address(this));

    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, JOB_REWARD);
  }

  function test_work_liquidation() public {
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    _workLiquidation(address(this), TKN, safeHandler);

    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, JOB_REWARD);
  }

  function test_work_update_collateral_price() public {
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    _workUpdateCollateralPrice(address(this), TKN);

    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, JOB_REWARD);
  }

  function test_work_update_rate() public {
    uint256 _initialBalance = systemCoin.balanceOf(address(this));
    _workUpdateRate(address(this));

    assertEq(systemCoin.balanceOf(address(this)) - _initialBalance, JOB_REWARD);
  }
}

// --- Scoped test contracts ---

contract E2EJobsTestDirectUser is DirectUser, E2EJobsTest {}

contract E2EJobsTestProxyUser is ProxyUser, E2EJobsTest {}
