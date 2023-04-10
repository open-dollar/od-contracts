pragma solidity ^0.6.7;

import "ds-test/test.sol";

import {BasicPIRawPerSecondCalculator} from '../../calculator/BasicPIRawPerSecondCalculator.sol';
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

contract BasicPIRawPerSecondCalculatorTest is DSTest {
    Hevm hevm;

    MockOracleRelayer oracleRelayer;
    MockPIRateSetter rateSetter;
    MockSetterRelayer setterRelayer;

    BasicPIRawPerSecondCalculator calculator;
    Feed orcl;

    int256 Kp                                 = int(EIGHTEEN_DECIMAL_NUMBER);
    int256 Ki                                 = int(EIGHTEEN_DECIMAL_NUMBER);
    uint256 integralPeriodSize                = 3600;
    uint256 baseUpdateCallerReward            = 10 ether;
    uint256 maxUpdateCallerReward             = 30 ether;
    uint256 perSecondCallerRewardIncrease     = 1000002763984612345119745925;
    uint256 perSecondCumulativeLeak           = 999997208243937652252849536; // 1% per hour
    uint8   integralGranularity               = 24;

    int256[] importedState = new int[](5);
    address self;

    function setUp() public {
      hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
      hevm.warp(604411200);

      oracleRelayer = new MockOracleRelayer();
      orcl = new Feed(1 ether, true);

      setterRelayer = new MockSetterRelayer(address(oracleRelayer));
      calculator = new BasicPIRawPerSecondCalculator(
        Kp,
        Ki,
        perSecondCumulativeLeak,
        integralPeriodSize,
        importedState
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

        assertEq(calculator.lut(), 0);
        assertEq(calculator.ips(), integralPeriodSize);
        assertEq(calculator.pdc(), 0);
        assertEq(calculator.pscl(), perSecondCumulativeLeak);
        assertEq(calculator.drr(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(Kp, calculator.ag());
        assertEq(Ki, calculator.sg());
        assertEq(calculator.oll(), 0);
        assertEq(calculator.tlv(), 0);
    }
    function test_modify_parameters() public {
        // Uint
        calculator.modifyParameters("ips", uint(2));
        calculator.modifyParameters("sg", int(1));
        calculator.modifyParameters("ag", int(1));
        calculator.modifyParameters("pscl", uint(TWENTY_SEVEN_DECIMAL_NUMBER - 5));

        assertEq(calculator.ips(), uint(2));
        assertEq(calculator.pscl(), TWENTY_SEVEN_DECIMAL_NUMBER - 5);

        assertEq(int(1), calculator.ag());
        assertEq(int(1), calculator.sg());
    }
    function test_get_new_rate_no_proportional_no_integral() public {
        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(EIGHTEEN_DECIMAL_NUMBER, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
        assertEq(newRedemptionRate, TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(pTerm, 0);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        // Verify that it did not change state
        assertEq(calculator.readers(address(this)), 1);
        assertEq(calculator.readers(address(rateSetter)), 1);
        assertEq(calculator.authorities(address(this)), 1);

        assertEq(calculator.lut(), 0);
        assertEq(calculator.ips(), integralPeriodSize);
        assertEq(calculator.pdc(), 0);
        assertEq(calculator.pscl(), perSecondCumulativeLeak);
        assertEq(calculator.drr(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(Kp, calculator.ag());
        assertEq(Ki, calculator.sg());
        assertEq(calculator.oll(), 0);
        assertEq(calculator.tlv(), 0);
    }
    function test_first_update_rate_no_deviation() public {
        hevm.warp(now + calculator.ips() + 1);

        rateSetter.updateRate(address(this));
        assertEq(uint(calculator.lut()), now);
        assertEq(uint(calculator.pdc()), 0);

        assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(oracleRelayer.redemptionRate(), TWENTY_SEVEN_DECIMAL_NUMBER);

        (uint timestamp, int proportional, int integral) =
          calculator.dos(calculator.oll() - 1);

        assertEq(timestamp, now);
        assertEq(proportional, 0);
        assertEq(integral, 0);
    }
    function testFail_update_invalid_market_price() public {
        orcl = new Feed(1 ether, false);
        rateSetter.modifyParameters("orcl", address(orcl));
        hevm.warp(now + calculator.ips() + 1);
        rateSetter.updateRate(address(this));
    }
    function testFail_update_same_period_warp() public {
        hevm.warp(now + calculator.ips() + 1);
        rateSetter.updateRate(address(this));
        rateSetter.updateRate(address(this));
    }
    function testFail_update_same_period_no_warp() public {
        rateSetter.updateRate(address(this));
        rateSetter.updateRate(address(this));
    }
    function test_get_new_rate_no_warp_zero_current_integral() public {
        orcl.updateTokenPrice(1.05E18); // 5% deviation

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
        assertEq(newRedemptionRate, 950000000000000000000000000);
        assertEq(pTerm, -0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, 1);

        orcl.updateTokenPrice(0.995E18); // -0.5% deviation

        (newRedemptionRate, pTerm, iTerm, rateTimeline) =
          calculator.getNextRedemptionRate(0.995E18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
        assertEq(newRedemptionRate, 1005000000000000000000000000);
        assertEq(pTerm, 0.005E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, 1);
    }
    function test_first_small_positive_deviation() public {
        assertEq(uint(calculator.pdc()), 0);

        hevm.warp(now + calculator.ips());
        orcl.updateTokenPrice(1.05E18);

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
        assertEq(newRedemptionRate, 0.95E27);
        assertEq(pTerm, -0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this)); // irrelevant because the contract computes everything by itself

        assertEq(uint(calculator.lut()), now);
        assertEq(calculator.pdc(), 0);
        assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(oracleRelayer.redemptionRate(), 0.95E27);

        (uint timestamp, int proportional, int integral) =
          calculator.dos(calculator.oll() - 1);

        assertEq(timestamp, now);
        assertEq(proportional, -0.05E27);
        assertEq(integral, 0);
    }
    function test_first_small_negative_deviation() public {
        assertEq(uint(calculator.pdc()), 0);

        hevm.warp(now + calculator.ips());

        orcl.updateTokenPrice(0.95E18);

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
        assertEq(newRedemptionRate, 1.05E27);
        assertEq(pTerm, 0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));

        assertEq(uint(calculator.lut()), now);
        assertEq(calculator.pdc(), 0);
        assertEq(oracleRelayer.redemptionPrice(), TWENTY_SEVEN_DECIMAL_NUMBER);
        assertEq(oracleRelayer.redemptionRate(), 1.05E27);
    }
    function test_leak_sets_integral_to_zero() public {
        assertEq(uint(calculator.pdc()), 0);

        calculator.modifyParameters("ag", int(1000));
        calculator.modifyParameters("pscl", uint(998721603904830360273103599)); // -99% per hour

        // First update
        hevm.warp(now + calculator.ips());
        orcl.updateTokenPrice(1 ether + 1);

        rateSetter.updateRate(address(this));

        // Second update
        hevm.warp(now + calculator.ips());
        orcl.updateTokenPrice(1 ether + 1);

        rateSetter.updateRate(address(this));

        // Third update
        orcl.updateTokenPrice(1 ether);
        hevm.warp(now + calculator.ips());

        oracleRelayer.redemptionPrice();
        oracleRelayer.modifyParameters("redemptionPrice", 1E27);
        oracleRelayer.modifyParameters("redemptionRate", 1E27);

        assertEq(oracleRelayer.redemptionRate(), 1E27);
        assertEq(orcl.read(), 1 ether);

        rateSetter.updateRate(address(this));
        oracleRelayer.modifyParameters("redemptionRate", 1E27);
        assertEq(oracleRelayer.redemptionRate(), 1E27);

        // Final update
        hevm.warp(now + calculator.ips() * 100);

        (uint newRedemptionRate, int pTerm, int iTerm,) =
          calculator.getNextRedemptionRate(1 ether, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 1E27);
        assertEq(pTerm, 0);
        assertEq(iTerm, 0);

        rateSetter.updateRate(address(this));
        assertEq(calculator.pdc(), 0);
    }
    function test_two_small_positive_deviations() public {
        assertEq(uint(calculator.pdc()), 0);

        hevm.warp(now + calculator.ips());

        orcl.updateTokenPrice(1.05E18);
        rateSetter.updateRate(address(this)); // -5% global rate

        hevm.warp(now + calculator.ips());
        assertEq(oracleRelayer.redemptionPrice(), 1);

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 999999999999999999999999999);
        assertEq(pTerm, -1049999999999999999999999999);
        assertEq(iTerm, -1979999999999999999999999996400);

        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));

        assertEq(uint(calculator.lut()), now);
        assertEq(calculator.pdc(), -1979999999999999999999999996400);
        assertEq(oracleRelayer.redemptionPrice(), 1);
        assertEq(oracleRelayer.redemptionRate(), 999999999999999999999999999);
    }
    function test_big_delay_positive_deviation() public {
        assertEq(uint(calculator.pdc()), 0);

        hevm.warp(now + calculator.ips());

        orcl.updateTokenPrice(1.05E18);
        rateSetter.updateRate(address(this));

        hevm.warp(now + calculator.ips() * 10); // 10 hours

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 999999999999999999999999999);
        assertEq(pTerm, -1049999999999999999999999999);
        assertEq(iTerm, -19799999999999999999999999964000);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));
    }
    function test_normalized_pi_result() public {
        assertEq(uint(calculator.pdc()), 0);

        hevm.warp(now + calculator.ips());
        orcl.updateTokenPrice(0.95E18);

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
        assertEq(newRedemptionRate, 1.05E27);
        assertEq(pTerm, 0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        Kp = Kp / int(4) / int(calculator.ips() * 24);
        Ki = Ki / int(4) / int(calculator.ips() ** 2) / 24;

        assertEq(Kp, 2893518518518);
        assertEq(Ki, 803755144);

        calculator.modifyParameters("sg", Kp);
        calculator.modifyParameters("ag", Ki);

        (int gainAdjustedP, int gainAdjustedI) = calculator.getGainAdjustedTerms(int(0.05E27), int(0));
        assertEq(gainAdjustedP, 144675925925900000000);
        assertEq(gainAdjustedI, 0);

        (newRedemptionRate, pTerm, iTerm, rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, TWENTY_SEVEN_DECIMAL_NUMBER, rateSetter.iapcr());
        assertEq(newRedemptionRate, 1000000144675925925900000000);
        assertEq(pTerm, 0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        rateSetter.updateRate(address(this));
        hevm.warp(now + calculator.ips());

        (newRedemptionRate, pTerm, iTerm, rateTimeline) =
          calculator.getNextRedemptionRate(0.95E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 1000000291613001814917161083);
        assertEq(pTerm, 50520968952868729114836237);
        assertEq(iTerm, 180937744115163712406705224800);
        assertEq(rateTimeline, defaultGlobalTimeline);
    }
    function testFail_redemption_way_higher_than_market() public {
        assertEq(uint(calculator.pdc()), 0);

        oracleRelayer.modifyParameters("redemptionPrice", FORTY_FIVE_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER);

        rateSetter.updateRate(address(this));
    }
    function test_correct_proportional_calculation() public {
        assertEq(uint(calculator.pdc()), 0);

        oracleRelayer.redemptionPrice();
        oracleRelayer.modifyParameters("redemptionPrice", 2E27);
        hevm.warp(now + calculator.ips());

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(2.05E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 0.95E27);
        assertEq(pTerm, -0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        Kp = Kp / 4 / int(calculator.ips()) / 96;
        Ki = 0;

        assertEq(Kp, 723379629629);
        assertEq(Ki, 0);
        assertEq(Kp * int(4 * calculator.ips() * 96), 999999999999129600);

        calculator.modifyParameters("sg", Kp);
        calculator.modifyParameters("ag", Ki);

        (newRedemptionRate, pTerm, iTerm, rateTimeline) =
          calculator.getNextRedemptionRate(2.05E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 999999963831018518550000000);
        assertEq(pTerm, -0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        (int gainAdjustedP,) = calculator.getGainAdjustedTerms(-int(0.05E27), int(0));
        assertEq(gainAdjustedP, -36168981481450000000);
        assertEq(gainAdjustedP * int(96) * int(calculator.ips()) * int(4), -49999999999956480000000000);

        (newRedemptionRate, pTerm, iTerm, rateTimeline) =
          calculator.getNextRedemptionRate(1.95E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 1000000036168981481450000000);
        assertEq(pTerm, 0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        (gainAdjustedP, ) = calculator.getGainAdjustedTerms(int(0.05E27), int(0));
        assertEq(gainAdjustedP, 36168981481450000000);
        assertEq(gainAdjustedP * int(96) * int(calculator.ips()) * int(4), 49999999999956480000000000);
    }
    function test_both_gains_zero() public {
        calculator.modifyParameters("sg", int(0));
        calculator.modifyParameters("ag", int(0));

        assertEq(uint(calculator.pdc()), 0);

        (uint newRedemptionRate, int pTerm, int iTerm, uint rateTimeline) =
          calculator.getNextRedemptionRate(1.05E18, oracleRelayer.redemptionPrice(), rateSetter.iapcr());
        assertEq(newRedemptionRate, 1E27);
        assertEq(pTerm, -0.05E27);
        assertEq(iTerm, 0);
        assertEq(rateTimeline, defaultGlobalTimeline);

        orcl.updateTokenPrice(1.05E18);
        rateSetter.updateRate(address(this));

        assertEq(oracleRelayer.redemptionPrice(), 1E27);
        assertEq(oracleRelayer.redemptionRate(), 1E27);
    }
}
