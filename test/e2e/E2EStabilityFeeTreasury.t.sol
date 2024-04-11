// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Common, TKN, RAY, COLLAT, DEBT} from './Common.t.sol';

import {BaseUser} from '@test/scopes/BaseUser.t.sol';
import {DirectUser} from '@test/scopes/DirectUser.t.sol';
import {ProxyUser} from '@test/scopes/ProxyUser.t.sol';

import {HOUR, YEAR} from '@libraries/Math.sol';

abstract contract E2EStabilityFeeTreasuryTest is BaseUser, Common {
  uint256 constant INITIAL_DEBT = 100_000_000e18;

  function _gatherFees() internal {
    // Opening a SAFE to generate stability fees
    address alice = address(0x420);

    _generateDebt(alice, address(collateralJoin[TKN]), int256(1000 * COLLAT), int256(DEBT));

    // Collecting fees for stabilityFeeTreasury
    _collectFees(TKN, YEAR * 100);
  }

  function test_give_funds() public {
    // Collecting fees for stabilityFeeTreasury
    _gatherFees();

    uint256 _coinBalance = safeEngine.coinBalance(address(stabilityFeeTreasury));

    // giving 25% of the balance to bob
    uint256 _rad = _coinBalance / 4;

    vm.prank(deployer);
    // Executing give funds method with the 25% of the balance
    stabilityFeeTreasury.giveFunds(bob, _rad);

    // Assertions
    assertEq(safeEngine.coinBalance(bob), _rad);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), _coinBalance - _rad);
  }

  function test_take_funds() public {
    uint256 _wad = INITIAL_DEBT;

    // opening alice safe
    _generateDebt({
      _user: alice,
      _collateralJoin: address(collateralJoin[TKN]),
      _deltaCollat: int256(1000 * _wad),
      _deltaDebt: int256(_wad)
    });

    vm.prank(alice);
    safeEngine.approveSAFEModification(address(stabilityFeeTreasury));
    _joinCoins(alice, _wad);

    vm.prank(deployer);
    // Executing take funds method with the 100% of alice's balance
    stabilityFeeTreasury.takeFunds(alice, _wad * RAY);

    // Assertions
    assertEq(safeEngine.coinBalance(alice), 0);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), _wad * RAY);
  }

  function test_pull_funds() public {
    // Collecting fees for stabilityFeeTreasury
    _gatherFees();

    uint256 _coinBalance = safeEngine.coinBalance(address(stabilityFeeTreasury));
    uint256 _previousAliceBalance = safeEngine.coinBalance(alice);

    vm.startPrank(deployer);
    // Executing pulling ~25% of funds and setting alice as destination
    uint256 _rad = _coinBalance / 4;
    uint256 _wad = _rad / RAY;
    _rad = _wad * RAY; // solves internal rounding errors

    // Set total allowance to _rad
    stabilityFeeTreasury.setTotalAllowance(deployer, _rad);
    stabilityFeeTreasury.pullFunds(alice, _wad);
    vm.stopPrank();

    // Assertions
    assertEq(safeEngine.coinBalance(alice), _previousAliceBalance + _rad);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), _coinBalance - _rad);
    assertEq(stabilityFeeTreasury.allowance(deployer).total, 0); // deployer used all allowance
    assertEq(stabilityFeeTreasury.pulledPerHour(deployer, block.timestamp / HOUR), _rad);
  }

  function test_transfer_surplus_funds() public {
    // Collecting fees for stabilityFeeTreasury
    _gatherFees();
    address _extraSurplusReceiver = stabilityFeeTreasury.extraSurplusReceiver();
    uint256 _coinBalance = safeEngine.coinBalance(address(stabilityFeeTreasury));
    uint256 _fundsToTransfer = _coinBalance - stabilityFeeTreasury.params().treasuryCapacity;
    uint256 _preexistentBalance = safeEngine.coinBalance(_extraSurplusReceiver);

    // Transfering extra surplus to the receiver, in this case to the accounting engine
    stabilityFeeTreasury.transferSurplusFunds();
    assertEq(safeEngine.coinBalance(_extraSurplusReceiver), _fundsToTransfer + _preexistentBalance);
    assertEq(stabilityFeeTreasury.latestSurplusTransferTime(), block.timestamp);
  }

  function test_repay_debt_before_pull() public {
    // Collecting fees for stabilityFeeTreasury
    _gatherFees();
    uint256 _coinBalance = safeEngine.coinBalance(address(stabilityFeeTreasury));
    uint256 _previousAliceBalance = safeEngine.coinBalance(alice);

    // Executing pulling ~25% of funds and setting alice as destination
    uint256 _rad = _coinBalance / 4;
    uint256 _wad = _rad / RAY;
    _rad = _wad * RAY; // solves internal rounding errors
    // Generating a debt worth 50% of the gathered fees
    uint256 _debt = _coinBalance / 2;

    // Generating a debt in stabilityFeeTreasury safe
    vm.startPrank(deployer);
    safeEngine.createUnbackedDebt({
      _debtDestination: address(stabilityFeeTreasury),
      _coinDestination: address(0),
      _rad: _debt
    });
    assertEq(safeEngine.debtBalance(address(stabilityFeeTreasury)), _debt);

    stabilityFeeTreasury.setTotalAllowance(deployer, _rad);
    stabilityFeeTreasury.pullFunds(alice, _wad);
    vm.stopPrank();

    // Assertions
    assertEq(safeEngine.coinBalance(alice), _previousAliceBalance + _rad);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), _coinBalance - _debt - _rad);
    assertEq(safeEngine.debtBalance(address(stabilityFeeTreasury)), 0);
  }

  function test_join_coins_before_pull() public {
    uint256 _wad = INITIAL_DEBT;

    // opening alice safe
    _generateDebt({
      _user: alice,
      _collateralJoin: address(collateralJoin[TKN]),
      _deltaCollat: int256(1000 * _wad),
      _deltaDebt: int256(_wad)
    });

    // Transferring coin tokens to stabilityFeeTreasury
    vm.startPrank(alice);
    systemCoin.transfer(address(stabilityFeeTreasury), _wad);
    vm.stopPrank();

    // Executing pulling 100% of funds and setting bob as destination
    vm.startPrank(deployer);
    stabilityFeeTreasury.setTotalAllowance(deployer, _wad * RAY);
    stabilityFeeTreasury.pullFunds(bob, _wad);
    vm.stopPrank();

    // Assertions
    assertEq(safeEngine.coinBalance(bob), _wad * RAY);
    assertEq(safeEngine.coinBalance(address(stabilityFeeTreasury)), 0);
  }
}

// --- Scoped test contracts ---

contract E2EStabilityFeeTreasuryTestDirectUser is DirectUser, E2EStabilityFeeTreasuryTest {}
