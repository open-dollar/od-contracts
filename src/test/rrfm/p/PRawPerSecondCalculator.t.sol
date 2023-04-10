pragma solidity ^0.6.7;

import "ds-test/test.sol";

import {PRawPerSecondCalculator} from '../../calculator/PRawPerSecondCalculator.sol';
import {MockSetterRelayer} from "../utils/mock/MockSetterRelayer.sol";
import {MockPIRateSetter} from "../utils/mock/MockPIRateSetter.sol";
import "../utils/mock/MockOracleRelayer.sol";

contract Feed {
    bytes32 public price;
    bool public validPrice;
    uint public lastUpdateTime;
    constructor(uint256 price_, bool validPrice_) public {
        price = bytes32(price_);
        validPrice = validPrice_;
        lastUpdateTime = now;
    }
    function updateTokenPrice(uint256 price_) external {
        price = bytes32(price_);
        lastUpdateTime = now;
    }
    function read() external view returns (uint256) {
        return uint(price);
    }
    function getResultWithValidity() external view returns (uint256, bool) {
        return (uint(price), validPrice);
    }
}

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract PRawPerSecondCalculatorTest is DSTest {
    Hevm hevm;

    MockOracleRelayer oracleRelayer;
    MockPIRateSetter rateSetter;
    MockSetterRelayer setterRelayer;

    PRawPerSecondCalculator calculator;
    Feed orcl;

    int256 Kp                              = int(EIGHTEEN_DECIMAL_NUMBER);
    uint256 periodSize                     = 3600;
    uint256 baseUpdateCallerReward         = 10 ether;
    uint256 maxUpdateCallerReward          = 30 ether;
    uint256 perSecondCallerRewardIncrease  = 1000002763984612345119745925;
    uint256 noiseBarrier                   = EIGHTEEN_DECIMAL_NUMBER;
    uint256 feedbackOutputUpperBound       = TWENTY_SEVEN_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER;
    int256  feedbackOutputLowerBound       = -int(NEGATIVE_RATE_LIMIT);

    address self;

    function setUp() public {
      hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
      hevm.warp(604411200);

      oracleRelayer = new MockOracleRelayer();
      orcl = new Feed(1 ether, true);

      setterRelayer = new MockSetterRelayer(address(oracleRelayer));
      calculator = new PRawPerSecondCalculator(
        Kp,
        periodSize,
        noiseBarrier,
        feedbackOutputUpperBound,
        feedbackOutputLowerBound
      );

      rateSetter = new MockPIRateSetter(address(orcl), address(oracleRelayer), address(calculator), address(setterRelayer));
      setterRelayer.modifyParameters("setter", address(rateSetter));
      calculator.modifyParameters("seedProposer", address(rateSetter));

      self = address(this);
    }

    // --- Math ---
    uint constant defaultGlobalTimeline       = 1;
    uint constant FORTY_FIVE_DECIMAL_NUMBER   = 10 ** 45;
    uint constant TWENTY_SEVEN_DECIMAL_NUMBER = 10 ** 27;
    uint constant EIGHTEEN_DECIMAL_NUMBER     = 10 ** 18;
    uint256 constant NEGATIVE_RATE_LIMIT      = TWENTY_SEVEN_DECIMAL_NUMBER - 1;

    function rpower(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, base)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function wmultiply(uint x, uint y) internal pure returns (uint z) {
        z = multiply(x, y) / EIGHTEEN_DECIMAL_NUMBER;
    }
    function rmultiply(uint x, uint y) internal pure returns (uint z) {
        z = multiply(x, y) / TWENTY_SEVEN_DECIMAL_NUMBER;
    }
    function rdivide(uint x, uint y) internal pure returns (uint z) {
        z = multiply(x, TWENTY_SEVEN_DECIMAL_NUMBER) / y;
    }

    function test_correct_setup() public {
        assertEq(calculator.readers(address(this)), 1);
        assertEq(calculator.readers(address(rateSetter)), 1);
        assertEq(calculator.authorities(address(this)), 1);

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
        calculator.modifyParameters("nb", EIGHTEEN_DECIMAL_NUMBER);
        calculator.modifyParameters("ps", uint(2));
        calculator.modifyParameters("sg", int(1));
        calculator.modifyParameters("foub", uint(TWENTY_SEVEN_DECIMAL_NUMBER + 1));
        calculator.modifyParameters("folb", -int(1));

        assertEq(calculator.nb(), EIGHTEEN_DECIMAL_NUMBER);
        assertEq(calculator.ps(), uint(2));
        assertEq(calculator.foub(), uint(TWENTY_SEVEN_DECIMAL_NUMBER + 1));
        assertEq(calculator.folb(), -int(1));

        assertEq(int(1), calculator.sg());
    }
    function test_get_new_rate_no_proportional() public {
        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(EIGHTEEN_DECIMAL_NUMBER, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
        assertEq(newRedemptionRate, TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(pTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        // Verify that it did not change state
        assertEq(calculator.readers(address(this)), 1);
        assertEq(calculator.readers(address(rateSetter)), 1);
        assertEq(calculator.authorities(address(this)), 1);

        assertEq(calculator.nb(), noiseBarrier);
        assertEq(calculator.foub(), feedbackOutputUpperBound);
        assertEq(calculator.folb(), feedbackOutputLowerBound);
        assertEq(calculator.lut(), 0);
        assertEq(calculator.ps(), periodSize);
        assertEq(calculator.drr(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(Kp, calculator.sg());
    }
    function test_first_update_rate_no_deviation() public {
        hevm.warp(now + calculator.ps() + 1);

        rateSetter.updateRate(address(this));
        assertEq(uint(calculator.lut()), now);

        assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(oracleRelayer.redemptionRate(), TWENTY_SEVEN_DECIMAL_NUMBER);
    }
    function testFail_update_invalid_market_price() public {
        orcl = new Feed(1 ether, false);
        rateSetter.modifyParameters("orcl", address(orcl));
        hevm.warp(now + calculator.ps() + 1);
        rateSetter.updateRate(address(this));
    }
    function testFail_update_same_period_warp() public {
        hevm.warp(now + calculator.ps() + 1);
        rateSetter.updateRate(address(this));
        rateSetter.updateRate(address(this));
    }
    function testFail_update_same_period_no_warp() public {
        rateSetter.updateRate(address(this));
        rateSetter.updateRate(address(this));
    }
    function test_get_new_rate_no_warp_zero_current_integral() public {
        calculator.modifyParameters("nb", uint(0.94E18));

        orcl.updateTokenPrice(1.05E18); // 5% deviation

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
        assertEq(newRedemptionRate, 1E27);
        assertEq(pTerm, -0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        orcl.updateTokenPrice(0.995E18); // -0.5% deviation

        (newRedemptionRate, pTerm, rateTimeline) =
          calculator.getNextRedemptionRate(0.995E18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
        assertEq(newRedemptionRate, 1E27);
        assertEq(pTerm, 0.005E27);
        assertEq(rateTimeline, defaultGlobalTimeline);
    }
    function test_first_small_positive_deviation() public {
        calculator.modifyParameters("nb", uint(0.995E18));

        hevm.warp(now + calculator.ps());
        orcl.updateTokenPrice(1.05E18);

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
        assertEq(newRedemptionRate, 0.95E27);
        assertEq(pTerm, -0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this)); // irrelevant because the contract computes everything by itself

        assertEq(uint(calculator.lut()), now);
        assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(oracleRelayer.redemptionRate(), 0.95E27);
    }
    function test_first_small_negative_deviation() public {
        calculator.modifyParameters("nb", uint(0.995E18));

        hevm.warp(now + calculator.ps());

        orcl.updateTokenPrice(0.95E18);

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
        assertEq(newRedemptionRate, 1.05E27);
        assertEq(pTerm, 0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));

        assertEq(uint(calculator.lut()), now);
        assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(oracleRelayer.redemptionRate(), 1.05E27);
    }
    function test_leak_sets_integral_to_zero() public {
        calculator.modifyParameters("nb", uint(1e18));

        // First update
        hevm.warp(now + calculator.ps());
        orcl.updateTokenPrice(1 ether + 1);

        rateSetter.updateRate(address(this));

        // Second update
        hevm.warp(now + calculator.ps());
        orcl.updateTokenPrice(1 ether + 1);

        rateSetter.updateRate(address(this));

        // Third update
        orcl.updateTokenPrice(1 ether);
        hevm.warp(now + calculator.ps());

        oracleRelayer.redemptionPrice();
        oracleRelayer.modifyParameters("redemptionPrice", 1E27);
        oracleRelayer.modifyParameters("redemptionRate", 1E27);

        assertEq(oracleRelayer.redemptionRate(), 1E27);
        assertEq(orcl.read(), 1 ether);

        rateSetter.updateRate(address(this));
        oracleRelayer.modifyParameters("redemptionRate", 1E27);
        assertEq(oracleRelayer.redemptionRate(), 1E27);

        // Final update
        hevm.warp(now + calculator.ps() * 100);

        (uint newRedemptionRate, int pTerm,) =
          calculator.getNextRedemptionRate(1 ether, oracleRelayer.redemptionPrice(), 0);
        assertEq(newRedemptionRate, 1E27);
        assertEq(pTerm, 0);

        rateSetter.updateRate(address(this));
    }
    function test_two_small_positive_deviations() public {
        calculator.modifyParameters("nb", uint(0.995E18));

        hevm.warp(now + calculator.ps());

        orcl.updateTokenPrice(1.05E18);
        rateSetter.updateRate(address(this)); // -5% global rate

        hevm.warp(now + calculator.ps());
        assertEq(oracleRelayer.redemptionPrice(), 1);

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 1);
        assertEq(pTerm, -1049999999999999999999999999);

        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));

        assertEq(uint(calculator.lut()), now);
        assertEq(oracleRelayer.redemptionPrice(), 1);
        assertEq(oracleRelayer.redemptionRate(), 1);
    }
    function test_big_delay_positive_deviation() public {
        calculator.modifyParameters("nb", uint(0.995E18));

        hevm.warp(now + calculator.ps());

        orcl.updateTokenPrice(1.05E18);
        rateSetter.updateRate(address(this));

        hevm.warp(now + calculator.ps() * 10); // 10 hours

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, oracleRelayer.redemptionPrice(), 0);
        assertEq(newRedemptionRate, 1);
        assertEq(pTerm, -1049999999999999999999999999);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));
    }
    function test_normalized_p_result() public {
        calculator.modifyParameters("nb", EIGHTEEN_DECIMAL_NUMBER - 1);

        hevm.warp(now + calculator.ps());
        orcl.updateTokenPrice(0.95E18);

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
        assertEq(newRedemptionRate, 1.05E27);
        assertEq(pTerm, 0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        Kp = Kp / int(4) / int(calculator.ps() * 24);
        assertEq(Kp, 2893518518518);

        calculator.modifyParameters("sg", Kp);

        (newRedemptionRate, pTerm, rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, TWENTY_SEVEN_DECIMAL_NUMBER, 0);
        assertEq(newRedemptionRate, 1000000144675925925900000000);
        assertEq(pTerm, 0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));
        hevm.warp(now + calculator.ps());

        (newRedemptionRate, pTerm, rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, oracleRelayer.redemptionPrice(), 0);
        assertEq(newRedemptionRate, 1000000146183359238598598834);
        assertEq(pTerm, 50520968952868729114836237);
        assertEq(rateTimeline, defaultGlobalTimeline);
    }
    function testFail_redemption_way_higher_than_market() public {
        calculator.modifyParameters("nb", EIGHTEEN_DECIMAL_NUMBER - 1);

        oracleRelayer.modifyParameters("redemptionPrice", FORTY_FIVE_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER);

        rateSetter.updateRate(address(this));
    }
    function test_correct_proportional_calculation() public {
        calculator.modifyParameters("nb", EIGHTEEN_DECIMAL_NUMBER - 1);

        oracleRelayer.redemptionPrice();
        oracleRelayer.modifyParameters("redemptionPrice", 2E27);
        hevm.warp(now + calculator.ps());

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(2.05E18, oracleRelayer.redemptionPrice(), 0);
        assertEq(newRedemptionRate, 0.95E27);
        assertEq(pTerm, -0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        Kp = Kp / 4 / int(calculator.ps()) / 96;

        assertEq(Kp, 723379629629);
        assertEq(Kp * int(4 * calculator.ps() * 96), 999999999999129600);

        calculator.modifyParameters("sg", Kp);

        (newRedemptionRate, pTerm, rateTimeline) =
          calculator.getNextRedemptionRate(2.05E18, oracleRelayer.redemptionPrice(), 0);
        assertEq(newRedemptionRate, 999999963831018518550000000);
        assertEq(pTerm, -0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        (newRedemptionRate, pTerm, rateTimeline) =
          calculator.getNextRedemptionRate(1.95E18, oracleRelayer.redemptionPrice(), 0);
        assertEq(newRedemptionRate, 1000000036168981481450000000);
        assertEq(pTerm, 0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);
    }
    function test_both_zero_gain() public {
        calculator.modifyParameters("sg", int(0));

        calculator.modifyParameters("nb", EIGHTEEN_DECIMAL_NUMBER - 1);

        (uint newRedemptionRate, int pTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, oracleRelayer.redemptionPrice(), 0);
        assertEq(newRedemptionRate, 1E27);
        assertEq(pTerm, -0.05E27);
        assertEq(rateTimeline, defaultGlobalTimeline);

        orcl.updateTokenPrice(1.05E18);
        rateSetter.updateRate(address(this));

        assertEq(oracleRelayer.redemptionPrice(), 1E27);
        assertEq(oracleRelayer.redemptionRate(), 1E27);
    }
}
