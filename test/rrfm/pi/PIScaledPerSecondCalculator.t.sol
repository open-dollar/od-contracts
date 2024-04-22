// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'ds-test/test.sol';

import {PIDController as PIScaledPerSecondCalculator, IPIDController} from '@contracts/PIDController.sol';

import {MockPIDRateSetter} from '../utils/mock/MockPIDRateSetter.sol';
import {MockOracleRelayer} from '../utils/mock/MockOracleRelayer.sol';
import {OracleForTest} from '@test/mocks/OracleForTest.sol';

import {Math} from '@libraries/Math.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract PIScaledPerSecondCalculatorTest is DSTest {
  using Math for uint256;

  Hevm hevm;

  MockOracleRelayer oracleRelayer;
  MockPIDRateSetter rateSetter;
  address setterRelayer;

  PIScaledPerSecondCalculator calculator;
  OracleForTest orcl;

  int256 Kp = int256(EIGHTEEN_DECIMAL_NUMBER);
  int256 Ki = int256(EIGHTEEN_DECIMAL_NUMBER);
  uint256 integralPeriodSize = 3600;
  uint256 perSecondCumulativeLeak = 999_997_208_243_937_652_252_849_536; // 1% per hour
  uint256 noiseBarrier = EIGHTEEN_DECIMAL_NUMBER;
  uint256 feedbackOutputUpperBound = TWENTY_SEVEN_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER;
  int256 feedbackOutputLowerBound = -int256(NEGATIVE_RATE_LIMIT);

  IPIDController.DeviationObservation importedState;

  address self;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    oracleRelayer = new MockOracleRelayer();
    orcl = new OracleForTest(1 ether);

    IPIDController.ControllerGains memory _pidControllerGains = IPIDController.ControllerGains({kp: Kp, ki: Ki});

    IPIDController.PIDControllerParams memory _pidControllerParams = IPIDController.PIDControllerParams({
      integralPeriodSize: integralPeriodSize,
      perSecondCumulativeLeak: perSecondCumulativeLeak,
      noiseBarrier: noiseBarrier,
      feedbackOutputUpperBound: feedbackOutputUpperBound,
      feedbackOutputLowerBound: feedbackOutputLowerBound
    });

    calculator = new PIScaledPerSecondCalculator(_pidControllerGains, _pidControllerParams, importedState);

    rateSetter =
      new MockPIDRateSetter(address(orcl), address(oracleRelayer), address(calculator), address(setterRelayer));
    calculator.modifyParameters('seedProposer', abi.encode(rateSetter));

    self = address(this);
  }

  // --- Math ---
  uint256 constant FORTY_FIVE_DECIMAL_NUMBER = 10 ** 45;
  uint256 constant TWENTY_SEVEN_DECIMAL_NUMBER = 10 ** 27;
  uint256 constant EIGHTEEN_DECIMAL_NUMBER = 10 ** 18;
  uint256 constant NEGATIVE_RATE_LIMIT = TWENTY_SEVEN_DECIMAL_NUMBER - 1;

  function rpower(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 { z := base }
        default { z := 0 }
      }
      default {
        switch mod(n, 2)
        case 0 { z := base }
        default { z := x }
        let half := div(base, 2) // for rounding.
        for { n := div(n, 2) } n { n := div(n, 2) } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) { revert(0, 0) }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) { revert(0, 0) }
          x := div(xxRound, base)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) { revert(0, 0) }
            z := div(zxRound, base)
          }
        }
      }
    }
  }

  function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  function wmultiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = multiply(x, y) / EIGHTEEN_DECIMAL_NUMBER;
  }

  function rmultiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = multiply(x, y) / TWENTY_SEVEN_DECIMAL_NUMBER;
  }

  function rdivide(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = multiply(x, TWENTY_SEVEN_DECIMAL_NUMBER) / y;
  }

  function test_correct_setup() public {
    // assertEq(calculator.readers(address(this)), 1);
    // assertEq(calculator.readers(address(rateSetter)), 1);
    assertTrue(calculator.authorizedAccounts(address(this)));

    assertEq(calculator.params().noiseBarrier, noiseBarrier);
    assertEq(calculator.params().feedbackOutputUpperBound, feedbackOutputUpperBound);
    assertEq(calculator.params().feedbackOutputLowerBound, feedbackOutputLowerBound);
    assertEq(calculator.deviationObservation().timestamp, 0);
    assertEq(calculator.params().integralPeriodSize, integralPeriodSize);
    assertEq(calculator.deviationObservation().integral, 0);
    assertEq(calculator.params().perSecondCumulativeLeak, perSecondCumulativeLeak);
    assertEq(Kp, calculator.controllerGains().ki);
    assertEq(Ki, calculator.controllerGains().kp);
    assertEq(calculator.timeSinceLastUpdate(), 0);
  }

  function test_modify_parameters() public {
    // Uint
    calculator.modifyParameters('noiseBarrier', abi.encode(EIGHTEEN_DECIMAL_NUMBER));
    calculator.modifyParameters('integralPeriodSize', abi.encode(uint256(2)));
    calculator.modifyParameters('kp', abi.encode(int256(1)));
    calculator.modifyParameters('ki', abi.encode(int256(1)));
    calculator.modifyParameters('feedbackOutputUpperBound', abi.encode(uint256(TWENTY_SEVEN_DECIMAL_NUMBER + 1)));
    calculator.modifyParameters('feedbackOutputLowerBound', abi.encode(-int256(1)));
    calculator.modifyParameters('perSecondCumulativeLeak', abi.encode(uint256(TWENTY_SEVEN_DECIMAL_NUMBER - 5)));

    assertEq(calculator.params().noiseBarrier, EIGHTEEN_DECIMAL_NUMBER);
    assertEq(calculator.params().integralPeriodSize, uint256(2));
    assertEq(calculator.params().feedbackOutputUpperBound, uint256(TWENTY_SEVEN_DECIMAL_NUMBER + 1));
    assertEq(calculator.params().feedbackOutputLowerBound, -int256(1));
    assertEq(calculator.params().perSecondCumulativeLeak, TWENTY_SEVEN_DECIMAL_NUMBER - 5);

    assertEq(int256(1), calculator.controllerGains().ki);
    assertEq(int256(1), calculator.controllerGains().kp);
  }

  function test_get_new_rate_no_proportional_no_integral() public {
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(EIGHTEEN_DECIMAL_NUMBER, TWENTY_SEVEN_DECIMAL_NUMBER, _iapcr);
    assertEq(newRedemptionRate, TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(pTerm, 0);
    assertEq(iTerm, 0);

    // Verify that it did not change state
    // assertEq(calculator.readers(address(this)), 1);
    // assertEq(calculator.readers(address(rateSetter)), 1);
    assertTrue(calculator.authorizedAccounts(address(this)));

    assertEq(calculator.params().noiseBarrier, noiseBarrier);
    assertEq(calculator.params().feedbackOutputUpperBound, feedbackOutputUpperBound);
    assertEq(calculator.params().feedbackOutputLowerBound, feedbackOutputLowerBound);
    assertEq(calculator.deviationObservation().timestamp, 0);
    assertEq(calculator.params().integralPeriodSize, integralPeriodSize);
    assertEq(calculator.deviationObservation().integral, 0);
    assertEq(calculator.params().perSecondCumulativeLeak, perSecondCumulativeLeak);
    assertEq(Kp, calculator.controllerGains().ki);
    assertEq(Ki, calculator.controllerGains().kp);
    assertEq(calculator.timeSinceLastUpdate(), 0);
  }

  function test_first_update_rate_no_deviation() public {
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize + 1);

    rateSetter.updateRate(address(this));
    assertEq(uint256(calculator.deviationObservation().timestamp), block.timestamp);
    assertEq(uint256(calculator.deviationObservation().integral), 0);

    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), TWENTY_SEVEN_DECIMAL_NUMBER);

    (IPIDController.DeviationObservation memory _deviation) = calculator.deviationObservation();

    assertEq(_deviation.timestamp, block.timestamp);
    assertEq(_deviation.proportional, 0);
    assertEq(_deviation.integral, 0);
  }

  function testFail_update_invalid_market_price() public {
    orcl = new OracleForTest(1 ether);
    orcl.setPriceAndValidity(1 ether, false);

    rateSetter.modifyParameters('orcl', address(orcl));
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize + 1);
    rateSetter.updateRate(address(this));
  }

  function testFail_update_same_period_warp() public {
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize + 1);
    rateSetter.updateRate(address(this));
    rateSetter.updateRate(address(this));
  }

  function testFail_update_same_period_no_warp() public {
    rateSetter.updateRate(address(this));
    rateSetter.updateRate(address(this));
  }

  function test_get_new_rate_no_warp_zero_current_integral() public {
    calculator.modifyParameters('noiseBarrier', abi.encode(uint256(0.94e18)));

    orcl.setPriceAndValidity(1.05e18, true); // 5% deviation
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, TWENTY_SEVEN_DECIMAL_NUMBER, _iapcr);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, -0.05e27);
    assertEq(iTerm, 0);

    orcl.setPriceAndValidity(0.995e18, true); // -0.5% deviation

    (newRedemptionRate, pTerm, iTerm) = calculator.getNextRedemptionRate(0.995e18, TWENTY_SEVEN_DECIMAL_NUMBER, _iapcr);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, 0.005e27);
    assertEq(iTerm, 0);
  }

  function test_first_small_positive_deviation() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);

    calculator.modifyParameters('noiseBarrier', abi.encode(uint256(0.995e18)));

    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);
    orcl.setPriceAndValidity(1.05e18, true);
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, TWENTY_SEVEN_DECIMAL_NUMBER, _iapcr);
    assertEq(newRedemptionRate, 0.95e27);
    assertEq(pTerm, -0.05e27);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this)); // irrelevant because the contract computes everything by itself

    assertEq(uint256(calculator.deviationObservation().timestamp), block.timestamp);
    assertEq(calculator.deviationObservation().integral, 0);
    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), 0.95e27);

    (IPIDController.DeviationObservation memory _deviation) = calculator.deviationObservation();

    assertEq(_deviation.timestamp, block.timestamp);
    assertEq(_deviation.proportional, -0.05e27);
    assertEq(_deviation.integral, 0);
  }

  function test_first_small_negative_deviation() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);

    calculator.modifyParameters('noiseBarrier', abi.encode(uint256(0.995e18)));

    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);

    orcl.setPriceAndValidity(0.95e18, true);
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, _iapcr);
    assertEq(newRedemptionRate, 1.05e27);
    assertEq(pTerm, 0.05e27);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this));

    assertEq(uint256(calculator.deviationObservation().timestamp), block.timestamp);
    assertEq(calculator.deviationObservation().integral, 0);
    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), 1.05e27);
  }

  function test_leak_sets_integral_to_zero() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);

    calculator.modifyParameters('noiseBarrier', abi.encode(uint256(1e18)));
    calculator.modifyParameters('ki', abi.encode(int256(1000)));
    calculator.modifyParameters('perSecondCumulativeLeak', abi.encode(uint256(998_721_603_904_830_360_273_103_599))); // -99% per hour

    // First update
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);
    orcl.setPriceAndValidity(1 ether + 1, true);

    rateSetter.updateRate(address(this));

    // Second update
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);
    orcl.setPriceAndValidity(1 ether + 1, true);

    rateSetter.updateRate(address(this));

    // Third update
    orcl.setPriceAndValidity(1 ether, true);
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);

    oracleRelayer.redemptionPrice();
    oracleRelayer.modifyParameters('redemptionPrice', 1e27);
    oracleRelayer.modifyParameters('redemptionRate', 1e27);

    assertEq(oracleRelayer.redemptionRate(), 1e27);
    assertEq(orcl.read(), 1 ether);

    rateSetter.updateRate(address(this));
    oracleRelayer.modifyParameters('redemptionRate', 1e27);
    assertEq(oracleRelayer.redemptionRate(), 1e27);

    // Final update
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize * 100);
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1 ether, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, 0);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this));
    assertEq(calculator.deviationObservation().integral, 0);
  }

  function test_two_small_positive_deviations() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);
    calculator.modifyParameters('noiseBarrier', abi.encode(uint256(0.995e18)));

    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);

    orcl.setPriceAndValidity(1.05e18, true);
    rateSetter.updateRate(address(this)); // -5% global rate

    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);
    assertEq(oracleRelayer.redemptionPrice(), 1);
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 1);
    assertEq(pTerm, -1_049_999_999_999_999_999_999_999_999_000_000_000_000_000_000_000_000_000);
    assertEq(iTerm, -1_889_999_999_999_999_999_999_999_998_290_000_000_000_000_000_000_000_000_000);

    rateSetter.updateRate(address(this));

    assertEq(uint256(calculator.deviationObservation().timestamp), block.timestamp);
    assertEq(
      calculator.deviationObservation().integral,
      -1_889_999_999_999_999_999_999_999_998_290_000_000_000_000_000_000_000_000_000
    );
    assertEq(oracleRelayer.redemptionPrice(), 1);
    assertEq(oracleRelayer.redemptionRate(), 1);
  }

  function test_big_delay_positive_deviation() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);
    calculator.modifyParameters('noiseBarrier', abi.encode(uint256(0.995e18)));

    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);

    orcl.setPriceAndValidity(1.05e18, true);
    rateSetter.updateRate(address(this));

    hevm.warp(block.timestamp + calculator.params().integralPeriodSize * 10); // 10 hours
    assertEq(oracleRelayer.redemptionPrice(), 1);
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 1);
    assertEq(pTerm, -1_049_999_999_999_999_999_999_999_999_000_000_000_000_000_000_000_000_000);
    assertEq(iTerm, -18_899_999_999_999_999_999_999_999_982_900_000_000_000_000_000_000_000_000_000);

    rateSetter.updateRate(address(this));
  }

  function test_normalized_pi_result() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);
    calculator.modifyParameters('noiseBarrier', abi.encode(EIGHTEEN_DECIMAL_NUMBER - 1));

    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);
    orcl.setPriceAndValidity(0.95e18, true);
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, _iapcr);
    assertEq(newRedemptionRate, 1.05e27);
    assertEq(pTerm, 0.05e27);
    assertEq(iTerm, 0);

    Kp = Kp / 4 / int256(calculator.params().integralPeriodSize * 24);
    Ki = Ki / 4 / int256(calculator.params().integralPeriodSize ** 2) / 24;

    assertEq(Kp, 2_893_518_518_518);
    assertEq(Ki, 803_755_144);

    calculator.modifyParameters('kp', abi.encode(Kp));
    calculator.modifyParameters('ki', abi.encode(Ki));

    (int256 gainAdjustedP, int256 gainAdjustedI) = calculator.getGainAdjustedTerms(int256(0.05e27), int256(0));
    assertEq(gainAdjustedP, 144_675_925_925_900_000_000);
    assertEq(gainAdjustedI, 0);

    (newRedemptionRate, pTerm, iTerm) = calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, _iapcr);
    assertEq(newRedemptionRate, 1_000_000_144_675_925_925_900_000_000);
    assertEq(pTerm, 0.05e27);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this));
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(0.95e18, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 1_000_000_291_498_825_809_688_551_682);
    assertEq(pTerm, 50_494_662_801_263_695_199_553_182);
    assertEq(iTerm, 180_890_393_042_274_651_359_195_727_600);
  }

  function testFail_redemption_way_higher_than_market() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);
    calculator.modifyParameters('noiseBarrier', abi.encode(EIGHTEEN_DECIMAL_NUMBER - 1));

    oracleRelayer.modifyParameters('redemptionPrice', FORTY_FIVE_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER);

    rateSetter.updateRate(address(this));
  }

  function test_correct_proportional_calculation() public {
    assertEq(uint256(calculator.deviationObservation().integral), 0);
    calculator.modifyParameters('noiseBarrier', abi.encode(EIGHTEEN_DECIMAL_NUMBER - 1));

    oracleRelayer.redemptionPrice();
    oracleRelayer.modifyParameters('redemptionPrice', 2e27);
    hevm.warp(block.timestamp + calculator.params().integralPeriodSize);
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(2.05e18, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 0.975e27);
    assertEq(pTerm, -0.025e27);
    assertEq(iTerm, 0);

    Kp = Kp / 4 / int256(calculator.params().integralPeriodSize) / 96;
    Ki = 0;

    assertEq(Kp, 723_379_629_629);
    assertEq(Ki, 0);
    assertEq(Kp * 4 * int256(calculator.params().integralPeriodSize) * 96, 999_999_999_999_129_600);

    calculator.modifyParameters('kp', abi.encode(Kp));
    calculator.modifyParameters('ki', abi.encode(Ki));

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(2.05e18, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 999_999_981_915_509_259_275_000_000);
    assertEq(pTerm, -0.025e27);
    assertEq(iTerm, 0);

    (int256 gainAdjustedP,) = calculator.getGainAdjustedTerms(-int256(0.025e27), int256(0));
    assertEq(gainAdjustedP, -18_084_490_740_725_000_000);
    assertEq(
      gainAdjustedP * int256(96) * int256(calculator.params().integralPeriodSize) * int256(4),
      -24_999_999_999_978_240_000_000_000
    );

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(1.95e18, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 1_000_000_018_084_490_740_725_000_000);
    assertEq(pTerm, 0.025e27);
    assertEq(iTerm, 0);

    (gainAdjustedP,) = calculator.getGainAdjustedTerms(int256(0.025e27), int256(0));
    assertEq(gainAdjustedP, 18_084_490_740_725_000_000);
    assertEq(
      gainAdjustedP * int256(96) * int256(calculator.params().integralPeriodSize) * int256(4),
      24_999_999_999_978_240_000_000_000
    );
  }

  function test_both_gains_zero() public {
    calculator.modifyParameters('kp', abi.encode(int256(0)));
    calculator.modifyParameters('ki', abi.encode(int256(0)));

    assertEq(uint256(calculator.deviationObservation().integral), 0);
    calculator.modifyParameters('noiseBarrier', abi.encode(EIGHTEEN_DECIMAL_NUMBER - 1));
    uint256 _iapcr = (calculator.params().perSecondCumulativeLeak).rpow(calculator.timeSinceLastUpdate());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), _iapcr);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, -0.05e27);
    assertEq(iTerm, 0);

    orcl.setPriceAndValidity(1.05e18, true);
    rateSetter.updateRate(address(this));

    assertEq(oracleRelayer.redemptionPrice(), 1e27);
    assertEq(oracleRelayer.redemptionRate(), 1e27);
  }
}
