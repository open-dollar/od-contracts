pragma solidity 0.8.19;

import 'ds-test/test.sol';

import {RawPIDController as PRawPerSecondCalculator} from '@contracts/for-test/RawPIDController.sol';
import {MockSetterRelayer} from '../utils/mock/MockSetterRelayer.sol';
import {MockPIDRateSetter} from '../utils/mock/MockPIDRateSetter.sol';
import '../utils/mock/MockOracleRelayer.sol';

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

contract PRawPerSecondCalculatorTest is DSTest {
  Hevm hevm;

  MockOracleRelayer oracleRelayer;
  MockPIDRateSetter rateSetter;
  MockSetterRelayer setterRelayer;

  PRawPerSecondCalculator calculator;
  Feed orcl;

  int256 Kp = int256(EIGHTEEN_DECIMAL_NUMBER);
  uint256 periodSize = 3600;
  uint256 noiseBarrier = EIGHTEEN_DECIMAL_NUMBER;
  uint256 feedbackOutputUpperBound = TWENTY_SEVEN_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER;
  int256 feedbackOutputLowerBound = -int256(NEGATIVE_RATE_LIMIT);

  address self;

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    hevm.warp(604_411_200);

    oracleRelayer = new MockOracleRelayer();
    orcl = new Feed(1 ether, true);

    setterRelayer = new MockSetterRelayer(address(oracleRelayer));
    calculator = new PRawPerSecondCalculator(
        Kp,
        0, // Ki
        TWENTY_SEVEN_DECIMAL_NUMBER, // perSecondCummulativeLeak
        periodSize,
        noiseBarrier,
        feedbackOutputUpperBound,
        feedbackOutputLowerBound,
        new int256[](0)
      );

    rateSetter =
      new MockPIDRateSetter(address(orcl), address(oracleRelayer), address(calculator), address(setterRelayer));
    setterRelayer.modifyParameters('setter', address(rateSetter));
    calculator.modifyParameters('seedProposer', address(rateSetter));

    self = address(this);
  }

  // --- Math ---
  uint256 constant defaultGlobalTimeline = 1;
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

    assertEq(calculator.nb(), noiseBarrier);
    assertEq(calculator.foub(), feedbackOutputUpperBound);
    assertEq(calculator.folb(), feedbackOutputLowerBound);
    assertEq(calculator.lut(), 0);
    assertEq(calculator.ps(), periodSize);
    assertEq(calculator.drr(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(Kp, calculator.sg());
  }

  function test_modify_parameters() public {
    // Uint
    calculator.modifyParameters('nb', EIGHTEEN_DECIMAL_NUMBER);
    calculator.modifyParameters('ps', uint256(2));
    calculator.modifyParameters('sg', int256(1));
    calculator.modifyParameters('foub', uint256(TWENTY_SEVEN_DECIMAL_NUMBER + 1));
    calculator.modifyParameters('folb', -int256(1));

    assertEq(calculator.nb(), EIGHTEEN_DECIMAL_NUMBER);
    assertEq(calculator.ps(), uint256(2));
    assertEq(calculator.foub(), uint256(TWENTY_SEVEN_DECIMAL_NUMBER + 1));
    assertEq(calculator.folb(), -int256(1));

    assertEq(int256(1), calculator.sg());
  }

  function test_get_new_rate_no_proportional() public {
    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(EIGHTEEN_DECIMAL_NUMBER, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
    assertEq(newRedemptionRate, TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(pTerm, 0);
    assertEq(rateTimeline, defaultGlobalTimeline);

    // Verify that it did not change state
    // assertEq(calculator.readers(address(this)), 1);
    // assertEq(calculator.readers(address(rateSetter)), 1);
    assertEq(calculator.authorizedAccounts(address(this)), 1);

    assertEq(calculator.nb(), noiseBarrier);
    assertEq(calculator.foub(), feedbackOutputUpperBound);
    assertEq(calculator.folb(), feedbackOutputLowerBound);
    assertEq(calculator.lut(), 0);
    assertEq(calculator.ps(), periodSize);
    assertEq(calculator.drr(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(Kp, calculator.sg());
  }

  function test_first_update_rate_no_deviation() public {
    hevm.warp(block.timestamp + calculator.ps() + 1);

    rateSetter.updateRate(address(this));
    assertEq(uint256(calculator.lut()), block.timestamp);

    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), TWENTY_SEVEN_DECIMAL_NUMBER);
  }

  function testFail_update_invalid_market_price() public {
    orcl = new Feed(1 ether, false);
    rateSetter.modifyParameters('orcl', address(orcl));
    hevm.warp(block.timestamp + calculator.ps() + 1);
    rateSetter.updateRate(address(this));
  }

  function testFail_update_same_period_warp() public {
    hevm.warp(block.timestamp + calculator.ps() + 1);
    rateSetter.updateRate(address(this));
    rateSetter.updateRate(address(this));
  }

  function testFail_update_same_period_no_warp() public {
    rateSetter.updateRate(address(this));
    rateSetter.updateRate(address(this));
  }

  function test_get_new_rate_no_warp_zero_current_integral() public {
    calculator.modifyParameters('nb', uint256(0.94e18));

    orcl.updateTokenPrice(1.05e18); // 5% deviation

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(1.05e18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, -0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    orcl.updateTokenPrice(0.995e18); // -0.5% deviation

    (newRedemptionRate, pTerm,, rateTimeline) =
      calculator.getNextRedemptionRate(0.995e18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, 0.005e27);
    assertEq(rateTimeline, defaultGlobalTimeline);
  }

  function test_first_small_positive_deviation() public {
    calculator.modifyParameters('nb', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.ps());
    orcl.updateTokenPrice(1.05e18);

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(1.05e18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
    assertEq(newRedemptionRate, 0.95e27);
    assertEq(pTerm, -0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    rateSetter.updateRate(address(this)); // irrelevant because the contract computes everything by itself

    assertEq(uint256(calculator.lut()), block.timestamp);
    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), 0.95e27);
  }

  function test_first_small_negative_deviation() public {
    calculator.modifyParameters('nb', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.ps());

    orcl.updateTokenPrice(0.95e18);

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
    assertEq(newRedemptionRate, 1.05e27);
    assertEq(pTerm, 0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    rateSetter.updateRate(address(this));

    assertEq(uint256(calculator.lut()), block.timestamp);
    assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
    assertEq(oracleRelayer.redemptionRate(), 1.05e27);
  }

  function test_leak_sets_integral_to_zero() public {
    calculator.modifyParameters('nb', uint256(1e18));

    // First update
    hevm.warp(block.timestamp + calculator.ps());
    orcl.updateTokenPrice(1 ether + 1);

    rateSetter.updateRate(address(this));

    // Second update
    hevm.warp(block.timestamp + calculator.ps());
    orcl.updateTokenPrice(1 ether + 1);

    rateSetter.updateRate(address(this));

    // Third update
    orcl.updateTokenPrice(1 ether);
    hevm.warp(block.timestamp + calculator.ps());

    oracleRelayer.redemptionPrice();
    oracleRelayer.modifyParameters('redemptionPrice', 1e27);
    oracleRelayer.modifyParameters('redemptionRate', 1e27);

    assertEq(oracleRelayer.redemptionRate(), 1e27);
    assertEq(orcl.read(), 1 ether);

    rateSetter.updateRate(address(this));
    oracleRelayer.modifyParameters('redemptionRate', 1e27);
    assertEq(oracleRelayer.redemptionRate(), 1e27);

    // Final update
    hevm.warp(block.timestamp + calculator.ps() * 100);

    (uint256 newRedemptionRate, int256 pTerm,,) =
      calculator.getNextRedemptionRate(1 ether, oracleRelayer.redemptionPrice(), 0);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, 0);

    rateSetter.updateRate(address(this));
  }

  function test_two_small_positive_deviations() public {
    calculator.modifyParameters('nb', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.ps());

    orcl.updateTokenPrice(1.05e18);
    rateSetter.updateRate(address(this)); // -5% global rate

    hevm.warp(block.timestamp + calculator.ps());
    assertEq(oracleRelayer.redemptionPrice(), 1);

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
    assertEq(newRedemptionRate, 1);
    assertEq(pTerm, -1_049_999_999_999_999_999_999_999_999);

    assertEq(rateTimeline, defaultGlobalTimeline);

    rateSetter.updateRate(address(this));

    assertEq(uint256(calculator.lut()), block.timestamp);
    assertEq(oracleRelayer.redemptionPrice(), 1);
    assertEq(oracleRelayer.redemptionRate(), 1);
  }

  function test_big_delay_positive_deviation() public {
    calculator.modifyParameters('nb', uint256(0.995e18));

    hevm.warp(block.timestamp + calculator.ps());

    orcl.updateTokenPrice(1.05e18);
    rateSetter.updateRate(address(this));

    hevm.warp(block.timestamp + calculator.ps() * 10); // 10 hours

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), 0);
    assertEq(newRedemptionRate, 1);
    assertEq(pTerm, -1_049_999_999_999_999_999_999_999_999);
    assertEq(rateTimeline, defaultGlobalTimeline);

    rateSetter.updateRate(address(this));
  }

  function test_normalized_p_result() public {
    calculator.modifyParameters('nb', EIGHTEEN_DECIMAL_NUMBER - 1);

    hevm.warp(block.timestamp + calculator.ps());
    orcl.updateTokenPrice(0.95e18);

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
    assertEq(newRedemptionRate, 1.05e27);
    assertEq(pTerm, 0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    Kp = Kp / int256(4) / int256(calculator.ps() * 24);
    assertEq(Kp, 2_893_518_518_518);

    calculator.modifyParameters('sg', Kp);

    (newRedemptionRate, pTerm,, rateTimeline) =
      calculator.getNextRedemptionRate(0.95e18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
    assertEq(newRedemptionRate, 1_000_000_144_675_925_925_900_000_000);
    assertEq(pTerm, 0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    rateSetter.updateRate(address(this));
    hevm.warp(block.timestamp + calculator.ps());

    (newRedemptionRate, pTerm,, rateTimeline) =
      calculator.getNextRedemptionRate(0.95e18, oracleRelayer.redemptionPrice(), 0);
    assertEq(newRedemptionRate, 1_000_000_146_183_359_238_598_598_834);
    assertEq(pTerm, 50_520_968_952_868_729_114_836_237);
    assertEq(rateTimeline, defaultGlobalTimeline);
  }

  function testFail_redemption_way_higher_than_market() public {
    calculator.modifyParameters('nb', EIGHTEEN_DECIMAL_NUMBER - 1);

    oracleRelayer.modifyParameters('redemptionPrice', FORTY_FIVE_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER);

    rateSetter.updateRate(address(this));
  }

  function test_correct_proportional_calculation() public {
    calculator.modifyParameters('nb', EIGHTEEN_DECIMAL_NUMBER - 1);

    oracleRelayer.redemptionPrice();
    oracleRelayer.modifyParameters('redemptionPrice', 2e27);
    hevm.warp(block.timestamp + calculator.ps());

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(2.05e18, oracleRelayer.redemptionPrice(), 0);
    assertEq(newRedemptionRate, 0.95e27);
    assertEq(pTerm, -0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    Kp = Kp / 4 / int256(calculator.ps()) / 96;

    assertEq(Kp, 723_379_629_629);
    assertEq(Kp * int256(4 * calculator.ps() * 96), 999_999_999_999_129_600);

    calculator.modifyParameters('sg', Kp);

    (newRedemptionRate, pTerm,, rateTimeline) =
      calculator.getNextRedemptionRate(2.05e18, oracleRelayer.redemptionPrice(), 0);
    assertEq(newRedemptionRate, 999_999_963_831_018_518_550_000_000);
    assertEq(pTerm, -0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    (newRedemptionRate, pTerm,, rateTimeline) =
      calculator.getNextRedemptionRate(1.95e18, oracleRelayer.redemptionPrice(), 0);
    assertEq(newRedemptionRate, 1_000_000_036_168_981_481_450_000_000);
    assertEq(pTerm, 0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);
  }

  function test_both_zero_gain() public {
    calculator.modifyParameters('sg', int256(0));

    calculator.modifyParameters('nb', EIGHTEEN_DECIMAL_NUMBER - 1);

    (uint256 newRedemptionRate, int256 pTerm,, uint256 rateTimeline) =
      calculator.getNextRedemptionRate(1.05e18, oracleRelayer.redemptionPrice(), 0);
    assertEq(newRedemptionRate, 1e27);
    assertEq(pTerm, -0.05e27);
    assertEq(rateTimeline, defaultGlobalTimeline);

    orcl.updateTokenPrice(1.05e18);
    rateSetter.updateRate(address(this));

    assertEq(oracleRelayer.redemptionPrice(), 1e27);
    assertEq(oracleRelayer.redemptionRate(), 1e27);
  }
}
