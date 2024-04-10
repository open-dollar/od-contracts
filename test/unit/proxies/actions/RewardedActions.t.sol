// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';

// Mock for testing ODProxy -> RewardActions
contract RewardActionsMock {
  address public accountingJob;
  address public coinJoin;
  uint256 public debtTimestamp;
  bytes32 public cType;
  address public safe;
  address public oracleJob;

  function startDebtAuction(address _accountingJob, address _coinJoin) external {
    accountingJob = _accountingJob;
    coinJoin = _coinJoin;
  }

  function startSurplusAuction(address _accountingJob, address _coinJoin) external {
    accountingJob = _accountingJob;
    coinJoin = _coinJoin;
  }

  function popDebtFromQueue(address _accountingJob, address _coinJoin, uint256 _debtTimestamp) external {
    accountingJob = _accountingJob;
    coinJoin = _coinJoin;
    debtTimestamp = _debtTimestamp;
  }

  function auctionSurplus(address _accountingJob, address _coinJoin) external {
    accountingJob = _accountingJob;
    coinJoin = _coinJoin;
  }

  function liquidateSAFE(address _liquidationJob, address _coinJoin, bytes32 _cType, address _safe) external {
    oracleJob = _liquidationJob;
    coinJoin = _coinJoin;
    cType = _cType;
    safe = _safe;
  }

  function updateCollateralPrice(address _oracleJob, address _coinJoin, bytes32 _cType) external {
    oracleJob = _oracleJob;
    coinJoin = _coinJoin;
    cType = _cType;
  }

  function updateRedemptionRate(address _oracleJob, address _coinJoin) external {
    oracleJob = _oracleJob;
    coinJoin = _coinJoin;
  }
}

// Testing the calls from ODProxy to RewardActions.
// In this test we don't care about the actual implementation of SurplusBidAction, only that the calls are made correctly
contract RewardActionsTest is ActionBaseTest {

  RewardActionsMock rewardActions;

  function setUp() public {
    proxy = new ODProxy(alice);
    rewardActions = new RewardActionsMock();
  }

  function test_callStartDebtAuction() public {
    vm.startPrank(alice);
    address target = address(rewardActions);
    address accountingJob = address(0x123);
    address coinJoin = address(0x456);

    proxy.execute(target, abi.encodeWithSignature('startDebtAuction(address,address)', accountingJob, coinJoin));

    address savedDataAccountingJob =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('accountingJob()')));
    address savedDataCoinJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));

    assertEq(savedDataAccountingJob, accountingJob);
    assertEq(savedDataCoinJoin, coinJoin);
  }

  function test_startSurplusAuction() public {
    vm.startPrank(alice);
    address target = address(rewardActions);
    address accountingJob = address(0x123);
    address coinJoin = address(0x456);

    proxy.execute(target, abi.encodeWithSignature('startSurplusAuction(address,address)', accountingJob, coinJoin));

    address savedDataAccountingJob =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('accountingJob()')));
    address savedDataCoinJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));

    assertEq(savedDataAccountingJob, accountingJob);
    assertEq(savedDataCoinJoin, coinJoin);
  }

  function test_popDebtFromQueue() public {
    vm.startPrank(alice);
    // function popDebtFromQueue(address _accountingJob, address _coinJoin, uint256 _debtTimestamp) external {
    address target = address(rewardActions);
    address accountingJob = address(0x123);
    address coinJoin = address(0x456);
    uint256 debtTimestamp = 123;

    proxy.execute(
      target,
      abi.encodeWithSignature('popDebtFromQueue(address,address,uint256)', accountingJob, coinJoin, debtTimestamp)
    );

    address savedDataAccountingJob =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('accountingJob()')));
    address savedDataCoinJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataDebtTimestamp =
      decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('debtTimestamp()')));

    assertEq(savedDataAccountingJob, accountingJob);
    assertEq(savedDataCoinJoin, coinJoin);
    assertEq(savedDataDebtTimestamp, debtTimestamp);
  }

  function test_auctionSurplus() public {
    vm.startPrank(alice);
    address target = address(rewardActions);
    address accountingJob = address(0x123);
    address coinJoin = address(0x456);

    proxy.execute(target, abi.encodeWithSignature('auctionSurplus(address,address)', accountingJob, coinJoin));

    address savedDataAccountingJob =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('accountingJob()')));
    address savedDataCoinJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));

    assertEq(savedDataAccountingJob, accountingJob);
    assertEq(savedDataCoinJoin, coinJoin);
  }

  function test_liquidateSAFE() public {
    vm.startPrank(alice);
    address target = address(rewardActions);
    address liquidationJob = address(0x123);
    address coinJoin = address(0x456);
    bytes32 cType = bytes32(uint256(1));
    address safe = address(0x789);

    proxy.execute(
      target,
      abi.encodeWithSignature('liquidateSAFE(address,address,bytes32,address)', liquidationJob, coinJoin, cType, safe)
    );

    address savedDataLiquidationJob =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('oracleJob()')));
    address savedDataCoinJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    bytes32 savedDataCType = bytes32(decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('cType()'))));
    address savedDataSafe = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('safe()')));

    assertEq(savedDataLiquidationJob, liquidationJob);
    assertEq(savedDataCoinJoin, coinJoin);
    assertEq(savedDataCType, cType);
    assertEq(savedDataSafe, safe);
  }

  function test_updateCollateralPrice() public {
    vm.startPrank(alice);
    address target = address(rewardActions);
    address oracleJob = address(0x123);
    address coinJoin = address(0x456);
    bytes32 cType = bytes32(uint256(1));

    proxy.execute(
      target, abi.encodeWithSignature('updateCollateralPrice(address,address,bytes32)', oracleJob, coinJoin, cType)
    );

    address savedDataOracleJob =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('oracleJob()')));
    address savedDataCoinJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    bytes32 savedDataCType = bytes32(decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('cType()'))));

    assertEq(savedDataOracleJob, oracleJob);
    assertEq(savedDataCoinJoin, coinJoin);
    assertEq(savedDataCType, cType);
  }

  function test_updateRedemptionRate() public {
    vm.startPrank(alice);
    address target = address(rewardActions);
    address oracleJob = address(0x123);
    address coinJoin = address(0x456);

    proxy.execute(target, abi.encodeWithSignature('updateRedemptionRate(address,address)', oracleJob, coinJoin));

    address savedDataOracleJob =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('oracleJob()')));
    address savedDataCoinJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));

    assertEq(savedDataOracleJob, oracleJob);
    assertEq(savedDataCoinJoin, coinJoin);
  }
}
