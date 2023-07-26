// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Common, ETH_A, COLLAT, DEBT} from './Common.t.sol';
import {JOB_REWARD} from '@script/Params.s.sol';

import {AccountingJob, IAccountingJob} from '@contracts/jobs/AccountingJob.sol';
import {LiquidationJob, ILiquidationJob} from '@contracts/jobs/LiquidationJob.sol';
import {OracleJob, IOracleJob} from '@contracts/jobs/OracleJob.sol';

import {RAY, YEAR} from '@libraries/Math.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';

abstract contract E2EJobsTest is BaseUser, Common {
  function setUp() public override {
    super.setUp();

    // Collecting fees for stabilityFeeTreasury
    _gatherFees(COLLAT, DEBT, YEAR * 10);
  }

  function _gatherFees(uint256 _deltaCollat, uint256 _deltaDebt, uint256 _timeElapsed) internal {
    // opening alice safe
    _generateDebt({
      _user: alice,
      _collateralJoin: address(collateralJoin[ETH_A]),
      _deltaCollat: int256(_deltaCollat),
      _deltaDebt: int256(_deltaDebt)
    });

    // Collecting fees
    _collectFees(ETH_A, _timeElapsed);
  }

  function test_work_pop_debt_from_queue(uint256 _debtBlock) public {
    vm.assume(_debtBlock != 0);
    vm.prank(deployer);
    accountingEngine.pushDebtToQueue(_debtBlock);
    uint256 _debtTimestamp = block.timestamp;
    vm.warp(_debtTimestamp + accountingEngine.params().popDebtDelay);

    _workPopDebtFromQueue(address(this), _debtTimestamp);

    assertEq(systemCoin.balanceOf(address(this)), JOB_REWARD);
  }

  function test_work_auction_debt() public {
    _liquidateSAFE(ETH_A, alice);
    accountingEngine.popDebtFromQueue(block.timestamp);

    _workAuctionDebt(address(this));

    assertEq(systemCoin.balanceOf(address(this)), JOB_REWARD);
  }

  function test_work_auction_surplus() public {
    _workAuctionSurplus(address(this));

    assertEq(systemCoin.balanceOf(address(this)), JOB_REWARD);
  }

  function test_work_transfer_extra_surplus() public {
    vm.startPrank(deployer);
    accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(1));
    accountingEngine.modifyParameters('extraSurplusReceiver', abi.encode(alice));
    vm.stopPrank();

    _workTransferExtraSurplus(address(this));

    assertEq(systemCoin.balanceOf(address(this)), JOB_REWARD);
  }

  function test_work_liquidation() public {
    _workLiquidation(address(this), ETH_A, alice);

    assertEq(systemCoin.balanceOf(address(this)), JOB_REWARD);
  }

  function test_work_update_collateral_price() public {
    _workUpdateCollateralPrice(address(this), ETH_A);

    assertEq(systemCoin.balanceOf(address(this)), JOB_REWARD);
  }

  function test_work_update_rate() public {
    _workUpdateRate(address(this));

    assertEq(systemCoin.balanceOf(address(this)), JOB_REWARD);
  }
}

// --- Scoped test contracts ---

contract E2EDirectUserJobsTest is DirectUser, E2EJobsTest {}

// TODO: uncomment after implementing Proxy actions for StabilityFeeTreasury and jobs
// contract E2EProxyUserJobsTest is ProxyUser, E2EJobsTest {}
