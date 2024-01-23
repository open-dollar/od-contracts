// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'ds-test/test.sol';

import {MockPIDCalculator} from '../utils/mock/MockPIDCalculator.sol';
import {IPIDRateSetter, PIDRateSetter} from '@contracts/PIDRateSetter.sol';
import {OracleForTest as OracleForTest} from '@testnet/mocks/OracleForTest.sol';

import {IOracleRelayer, OracleRelayer as MockOracleRelayer} from '@contracts/OracleRelayer.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;

  function etch(address, bytes memory) public virtual;
}

contract PIDRateSetterTest is DSTest {
  Hevm hevm;

  MockOracleRelayer oracleRelayer;

  IPIDRateSetter rateSetter;

  MockPIDCalculator calculator;
  OracleForTest orcl;

  uint256 periodSize = 3600;

  uint256 RAY = 10 ** 27;
  uint256 WAD = 10 ** 18;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    orcl = new OracleForTest(1 ether);

    hevm.etch(address(69), '0xF');

    IOracleRelayer.OracleRelayerParams memory _oracleRelayerParams =
      IOracleRelayer.OracleRelayerParams({redemptionRateUpperBound: RAY * WAD, redemptionRateLowerBound: 1});
    oracleRelayer = new MockOracleRelayer(address(69), orcl, _oracleRelayerParams);

    calculator = new MockPIDCalculator();
    rateSetter =
      new PIDRateSetter(address(oracleRelayer), address(calculator), IPIDRateSetter.PIDRateSetterParams(periodSize));
    oracleRelayer.addAuthorization(address(rateSetter));
  }

  function test_correct_setup() public {
    assertTrue(rateSetter.authorizedAccounts(address(this)));
    assertEq(rateSetter.params().updateRateDelay, periodSize);
  }

  function test_modify_parameters() public {
    address _newAddress = address(0x10000);
    hevm.etch(_newAddress, '0xF');

    // Modify
    rateSetter.modifyParameters('oracleRelayer', abi.encode(_newAddress));
    rateSetter.modifyParameters('pidCalculator', abi.encode(_newAddress));
    rateSetter.modifyParameters('updateRateDelay', abi.encode(1));

    // Check
    assertTrue(address(rateSetter.oracleRelayer()) == address(_newAddress));
    assertTrue(address(rateSetter.pidCalculator()) == address(_newAddress));

    assertEq(rateSetter.params().updateRateDelay, 1);
  }

  function test_first_update_rate_no_warp() public {
    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY + 2);
  }

  function test_first_update_rate_with_warp() public {
    hevm.warp(block.timestamp + periodSize);
    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY + 2);
  }

  function testFail_update_before_period_passed() public {
    rateSetter.updateRate();
    rateSetter.updateRate();
  }

  function test_two_updates() public {
    hevm.warp(block.timestamp + periodSize);
    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY + 2);

    hevm.warp(block.timestamp + periodSize);
    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY + 2);
  }

  function test_null_rate_needed_submit_different() public {
    calculator.toggleValidated();
    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY - 2);

    hevm.warp(block.timestamp + periodSize);
    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY - 2);
  }

  function test_wait_more_than_maxRewardIncreaseDelay_since_last_update() public {
    hevm.warp(block.timestamp + periodSize);
    rateSetter.updateRate();

    hevm.warp(block.timestamp + periodSize * 100_000 + 1);
    assertEq(block.timestamp - rateSetter.lastUpdateTime() - rateSetter.params().updateRateDelay, 359_996_401);

    rateSetter.updateRate();
  }

  function test_oracle_relayer_bounded_rate() public {
    oracleRelayer.modifyParameters('redemptionRateUpperBound', abi.encode(RAY + 1));
    oracleRelayer.modifyParameters('redemptionRateLowerBound', abi.encode(RAY - 1));

    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY + 1);

    calculator.toggleValidated();

    hevm.warp(block.timestamp + periodSize);
    rateSetter.updateRate();
    assertEq(oracleRelayer.redemptionRate(), RAY - 1);
  }
}
