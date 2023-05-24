// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'ds-test/test.sol';

import {PIDController as PIScaledPerSecondCalculator} from '@contracts/PIDController.sol';

import {MockPIDRateSetter} from '../utils/mock/MockPIDRateSetter.sol';
import {MockSetterRelayer} from '../utils/mock/MockSetterRelayer.sol';
import {MockOracleRelayer} from '../utils/mock/MockOracleRelayer.sol';

contract Feed {
  bytes32 public price;
  bool public validPrice;
  uint256 public lastUpdateTime;

  constructor(uint256 price_, bool validPrice_) {
    price = bytes32(price_);
    validPrice = validPrice_;
    lastUpdateTime = block.timestamp;
  }

  function updateTokenPrice(uint256 price_) external {
    price = bytes32(price_);
    lastUpdateTime = block.timestamp;
  }

  function read() external view returns (uint256) {
    return uint256(price);
  }

  function getResultWithValidity() external view returns (uint256, bool) {
    return (uint256(price), validPrice);
  }
}

abstract contract Hevm {
  function warp(uint256) public virtual;
}

contract PIScaledPerSecondCalculatorTest is DSTest {
  Hevm hevm;

  MockOracleRelayer oracleRelayer;
  MockPIDRateSetter rateSetter;
  MockSetterRelayer setterRelayer;

  PIScaledPerSecondCalculator calculator;
  Feed orcl;

  int256 Kp = int256(EIGHTEEN_DECIMAL_NUMBER);
  int256 Ki = int256(EIGHTEEN_DECIMAL_NUMBER);
  uint256 integralPeriodSize = 3600;
  uint256 perSecondCumulativeLeak = 999_997_208_243_937_652_252_849_536; // 1% per hour
  uint256 noiseBarrier = EIGHTEEN_DECIMAL_NUMBER;
  uint256 feedbackOutputUpperBound = TWENTY_SEVEN_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER;
  int256 feedbackOutputLowerBound = -int256(NEGATIVE_RATE_LIMIT);

  int256[] importedState = new int[](5);
  address self;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    oracleRelayer = new MockOracleRelayer();
    orcl = new Feed(1 ether, true);

    setterRelayer = new MockSetterRelayer(address(oracleRelayer));
    calculator = new PIScaledPerSecondCalculator(
        Kp,
        Ki,
        perSecondCumulativeLeak,
        integralPeriodSize,
        noiseBarrier,
        feedbackOutputUpperBound,
        feedbackOutputLowerBound,
        importedState
      );

    rateSetter =
      new MockPIDRateSetter(address(orcl), address(oracleRelayer), address(calculator), address(setterRelayer));
    setterRelayer.modifyParameters('setter', address(rateSetter));
    calculator.modifyParameters('seedProposer', address(rateSetter));

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
    assertEq(calculator.authorizedAccounts(address(this)), 1);

    assertEq(calculator.noiseBarrier(), noiseBarrier);
    assertEq(calculator.feedbackOutputUpperBound(), feedbackOutputUpperBound);
    assertEq(calculator.feedbackOutputLowerBound(), feedbackOutputLowerBound);
    assertEq(calculator.lastUpdateTime(), 0);
    assertEq(calculator.integralPeriodSize(), integralPeriodSize);
    assertEq(calculator.priceDeviationCumulative(), 0);
    assertEq(calculator.perSecondCumulativeLeak(), perSecondCumulativeLeak);
    assertEq(Kp, calculator.controllerGains().Ki);
    assertEq(Ki, calculator.controllerGains().Kp);
    assertEq(calculator.oll(), 0);
    assertEq(calculator.timeSinceLastUpdate(), 0);
  }

  function test_modify_parameters() public {
    // Uint
    calculator.modifyParameters('noiseBarrier', EIGHTEEN_DECIMAL_NUMBER);
    calculator.modifyParameters('integralPeriodSize', uint256(2));
    calculator.modifyParameters('kp', int256(1));
    calculator.modifyParameters('ki', int256(1));
    calculator.modifyParameters('feedbackOutputUpperBound', uint256(TWENTY_SEVEN_DECIMAL_NUMBER + 1));
    calculator.modifyParameters('feedbackOutputLowerBound', -int256(1));
    calculator.modifyParameters('perSecondCumulativeLeak', uint256(TWENTY_SEVEN_DECIMAL_NUMBER - 5));

    assertEq(calculator.noiseBarrier(), EIGHTEEN_DECIMAL_NUMBER);
    assertEq(calculator.integralPeriodSize(), uint256(2));
    assertEq(calculator.feedbackOutputUpperBound(), uint256(TWENTY_SEVEN_DECIMAL_NUMBER + 1));
    assertEq(calculator.feedbackOutputLowerBound(), -int256(1));
    assertEq(calculator.perSecondCumulativeLeak(), TWENTY_SEVEN_DECIMAL_NUMBER - 5);

    assertEq(int256(1), calculator.controllerGains().Ki);
    assertEq(int256(1), calculator.controllerGains().Kp);
  }

  function test_get_new_rate_no_proportional_no_integral() public {
    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(EIGHTEEN_DECIMAL_NUMBER, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
    assertEq(newRedemptionRate, TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(pTerm, 0);
    assertEq(iTerm, 0);

    // Verify that it did not change state
    // assertEq(calculator.readers(address(this)), 1);
    // assertEq(calculator.readers(address(rateSetter)), 1);
    assertEq(calculator.authorizedAccounts(address(this)), 1);

    assertEq(calculator.noiseBarrier(), noiseBarrier);
    assertEq(calculator.feedbackOutputUpperBound(), feedbackOutputUpperBound);
    assertEq(calculator.feedbackOutputLowerBound(), feedbackOutputLowerBound);
    assertEq(calculator.lastUpdateTime(), 0);
    assertEq(calculator.integralPeriodSize(), integralPeriodSize);
    assertEq(calculator.priceDeviationCumulative(), 0);
    assertEq(calculator.perSecondCumulativeLeak(), perSecondCumulativeLeak);
    assertEq(Kp, calculator.controllerGains().Ki);
    assertEq(Ki, calculator.controllerGains().Kp);
    assertEq(calculator.oll(), 0);
    assertEq(calculator.timeSinceLastUpdate(), 0);
  }

  function test_first_update_rate_no_deviation() public {
    hevm.warp(block.timestamp + calculator.integralPeriodSize() + 1);

    rateSetter.updateRate(address(this));
    assertEq(uint256(calculator.lastUpdateTime()), block.timestamp);
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);

    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), TWENTY_SEVEN_DECIMAL_NUMBER);

    (uint256 timestamp, int256 proportional, int256 integral) = calculator.deviationObservations(calculator.oll() - 1);

    assertEq(timestamp, block.timestamp);
    assertEq(proportional, 0);
    assertEq(integral, 0);
  }

  function testFail_update_invalid_market_price() public {
    orcl = new Feed(1 ether, false);
    rateSetter.modifyParameters('orcl', address(orcl));
    hevm.warp(block.timestamp + calculator.integralPeriodSize() + 1);
    rateSetter.updateRate(address(this));
  }

  function testFail_update_same_period_warp() public {
    hevm.warp(block.timestamp + calculator.integralPeriodSize() + 1);
    rateSetter.updateRate(address(this));
    rateSetter.updateRate(address(this));
  }

  function testFail_update_same_period_no_warp() public {
    rateSetter.updateRate(address(this));
    rateSetter.updateRate(address(this));
  }

  function test_get_new_rate_no_warp_zero_current_integral() public {
    calculator.modifyParameters('noiseBarrier', uint256(0.94e18));

    orcl.updateTokenPrice(1.05e18); // 5% deviation

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, -0.05e27);
    assertEq(iTerm, 0);

    orcl.updateTokenPrice(0.995e18); // -0.5% deviation

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(0.995e18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, 0.005e27);
    assertEq(iTerm, 0);
  }

  function test_first_small_positive_deviation() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);

    calculator.modifyParameters('noiseBarrier', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.integralPeriodSize());
    orcl.updateTokenPrice(1.05e18);

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
    assertEq(newRedemptionRate, 0.95e27);
    assertEq(pTerm, -0.05e27);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this)); // irrelevant because the contract computes everything by itself

    assertEq(uint256(calculator.lastUpdateTime()), block.timestamp);
    assertEq(calculator.priceDeviationCumulative(), 0);
    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), 0.95e27);

    (uint256 timestamp, int256 proportional, int256 integral) = calculator.deviationObservations(calculator.oll() - 1);

    assertEq(timestamp, block.timestamp);
    assertEq(proportional, -0.05e27);
    assertEq(integral, 0);
  }

  function test_first_small_negative_deviation() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);

    calculator.modifyParameters('noiseBarrier', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.integralPeriodSize());

    orcl.updateTokenPrice(0.95e18);

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
    assertEq(newRedemptionRate, 1.05e27);
    assertEq(pTerm, 0.05e27);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this));

    assertEq(uint256(calculator.lastUpdateTime()), block.timestamp);
    assertEq(calculator.priceDeviationCumulative(), 0);
    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), 1.05e27);
  }

  function test_leak_sets_integral_to_zero() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);

    calculator.modifyParameters('noiseBarrier', uint256(1e18));
    calculator.modifyParameters('ki', int256(1000));
    calculator.modifyParameters('perSecondCumulativeLeak', uint256(998_721_603_904_830_360_273_103_599)); // -99% per hour

    // First update
    hevm.warp(block.timestamp + calculator.integralPeriodSize());
    orcl.updateTokenPrice(1 ether + 1);

    rateSetter.updateRate(address(this));

    // Second update
    hevm.warp(block.timestamp + calculator.integralPeriodSize());
    orcl.updateTokenPrice(1 ether + 1);

    rateSetter.updateRate(address(this));

    // Third update
    orcl.updateTokenPrice(1 ether);
    hevm.warp(block.timestamp + calculator.integralPeriodSize());

    oracleRelayer.redemptionPrice();
    oracleRelayer.modifyParameters('redemptionPrice', 1e27);
    oracleRelayer.modifyParameters('redemptionRate', 1e27);

    assertEq(oracleRelayer.redemptionRate(), 1e27);
    assertEq(orcl.read(), 1 ether);

    rateSetter.updateRate(address(this));
    oracleRelayer.modifyParameters('redemptionRate', 1e27);
    assertEq(oracleRelayer.redemptionRate(), 1e27);

    // Final update
    hevm.warp(block.timestamp + calculator.integralPeriodSize() * 100);

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1 ether, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, 0);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this));
    assertEq(calculator.priceDeviationCumulative(), 0);
  }

  function test_two_small_positive_deviations() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);
    calculator.modifyParameters('noiseBarrier', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.integralPeriodSize());

    orcl.updateTokenPrice(1.05e18);
    rateSetter.updateRate(address(this)); // -5% global rate

    hevm.warp(block.timestamp + calculator.integralPeriodSize());
    assertEq(oracleRelayer.redemptionPrice(), 1);

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 1);
    assertEq(pTerm, -1_049_999_999_999_999_999_999_999_999_000_000_000_000_000_000_000_000_000);
    assertEq(iTerm, -1_889_999_999_999_999_999_999_999_998_290_000_000_000_000_000_000_000_000_000);

    rateSetter.updateRate(address(this));

    assertEq(uint256(calculator.lastUpdateTime()), block.timestamp);
    assertEq(
      calculator.priceDeviationCumulative(),
      -1_889_999_999_999_999_999_999_999_998_290_000_000_000_000_000_000_000_000_000
    );
    assertEq(oracleRelayer.redemptionPrice(), 1);
    assertEq(oracleRelayer.redemptionRate(), 1);
  }

  function test_big_delay_positive_deviation() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);
    calculator.modifyParameters('noiseBarrier', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.integralPeriodSize());

    orcl.updateTokenPrice(1.05e18);
    rateSetter.updateRate(address(this));

    hevm.warp(block.timestamp + calculator.integralPeriodSize() * 10); // 10 hours
    assertEq(oracleRelayer.redemptionPrice(), 1);

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 1);
    assertEq(pTerm, -1_049_999_999_999_999_999_999_999_999_000_000_000_000_000_000_000_000_000);
    assertEq(iTerm, -18_899_999_999_999_999_999_999_999_982_900_000_000_000_000_000_000_000_000_000);

    rateSetter.updateRate(address(this));
  }

  function test_normalized_pi_result() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);
    calculator.modifyParameters('noiseBarrier', EIGHTEEN_DECIMAL_NUMBER - 1);

    hevm.warp(block.timestamp + calculator.integralPeriodSize());
    orcl.updateTokenPrice(0.95e18);

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
    assertEq(newRedemptionRate, 1.05e27);
    assertEq(pTerm, 0.05e27);
    assertEq(iTerm, 0);

    Kp = Kp / 4 / int256(calculator.integralPeriodSize() * 24);
    Ki = Ki / 4 / int256(calculator.integralPeriodSize() ** 2) / 24;

    assertEq(Kp, 2_893_518_518_518);
    assertEq(Ki, 803_755_144);

    calculator.modifyParameters('kp', Kp);
    calculator.modifyParameters('ki', Ki);

    (int256 gainAdjustedP, int256 gainAdjustedI) = calculator.getGainAdjustedTerms(int256(0.05e27), int256(0));
    assertEq(gainAdjustedP, 144_675_925_925_900_000_000);
    assertEq(gainAdjustedI, 0);

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
    assertEq(newRedemptionRate, 1_000_000_144_675_925_925_900_000_000);
    assertEq(pTerm, 0.05e27);
    assertEq(iTerm, 0);

    rateSetter.updateRate(address(this));
    hevm.warp(block.timestamp + calculator.integralPeriodSize());

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(0.95e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 1_000_000_291_498_825_809_688_551_682);
    assertEq(pTerm, 50_494_662_801_263_695_199_553_182);
    assertEq(iTerm, 180_890_393_042_274_651_359_195_727_600);
  }

  function testFail_redemption_way_higher_than_market() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);
    calculator.modifyParameters('noiseBarrier', EIGHTEEN_DECIMAL_NUMBER - 1);

    oracleRelayer.modifyParameters('redemptionPrice', FORTY_FIVE_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER);

    rateSetter.updateRate(address(this));
  }

  function test_correct_proportional_calculation() public {
    assertEq(uint256(calculator.priceDeviationCumulative()), 0);
    calculator.modifyParameters('noiseBarrier', EIGHTEEN_DECIMAL_NUMBER - 1);

    oracleRelayer.redemptionPrice();
    oracleRelayer.modifyParameters('redemptionPrice', 2e27);
    hevm.warp(block.timestamp + calculator.integralPeriodSize());

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(2.05e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 0.975e27);
    assertEq(pTerm, -0.025e27);
    assertEq(iTerm, 0);

    Kp = Kp / 4 / int256(calculator.integralPeriodSize()) / 96;
    Ki = 0;

    assertEq(Kp, 723_379_629_629);
    assertEq(Ki, 0);
    assertEq(Kp * 4 * int256(calculator.integralPeriodSize()) * 96, 999_999_999_999_129_600);

    calculator.modifyParameters('kp', Kp);
    calculator.modifyParameters('ki', Ki);

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(2.05e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 999_999_981_915_509_259_275_000_000);
    assertEq(pTerm, -0.025e27);
    assertEq(iTerm, 0);

    (int256 gainAdjustedP,) = calculator.getGainAdjustedTerms(-int256(0.025e27), int256(0));
    assertEq(gainAdjustedP, -18_084_490_740_725_000_000);
    assertEq(
      gainAdjustedP * int256(96) * int256(calculator.integralPeriodSize()) * int256(4),
      -24_999_999_999_978_240_000_000_000
    );

    (newRedemptionRate, pTerm, iTerm) =
      calculator.getNextRedemptionRate(1.95e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 1_000_000_018_084_490_740_725_000_000);
    assertEq(pTerm, 0.025e27);
    assertEq(iTerm, 0);

    (gainAdjustedP,) = calculator.getGainAdjustedTerms(int256(0.025e27), int256(0));
    assertEq(gainAdjustedP, 18_084_490_740_725_000_000);
    assertEq(
      gainAdjustedP * int256(96) * int256(calculator.integralPeriodSize()) * int256(4),
      24_999_999_999_978_240_000_000_000
    );
  }

  function test_both_gains_zero() public {
    calculator.modifyParameters('kp', int256(0));
    calculator.modifyParameters('ki', int256(0));

    assertEq(uint256(calculator.priceDeviationCumulative()), 0);
    calculator.modifyParameters('noiseBarrier', EIGHTEEN_DECIMAL_NUMBER - 1);

    (uint256 newRedemptionRate, int256 pTerm, int256 iTerm) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, -0.05e27);
    assertEq(iTerm, 0);

    orcl.updateTokenPrice(1.05e18);
    rateSetter.updateRate(address(this));

    assertEq(oracleRelayer.redemptionPrice(), 1e27);
    assertEq(oracleRelayer.redemptionRate(), 1e27);
  }
}
