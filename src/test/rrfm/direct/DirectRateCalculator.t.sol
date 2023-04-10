pragma solidity 0.6.7;

import "ds-test/test.sol";

import {DirectRateCalculator} from '../../calculator/DirectRateCalculator.sol';
import {MockSetterRelayer} from "../utils/mock/MockSetterRelayer.sol";
import {MockDirectRateSetter} from "../utils/mock/MockDirectRateSetter.sol";
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

contract DirectRateCalculatorTest is DSTest {
    Hevm hevm;

    MockOracleRelayer oracleRelayer;
    MockDirectRateSetter rateSetter;
    MockSetterRelayer setterRelayer;

    DirectRateCalculator calculator;
    Feed orcl;

    uint256 acceleration = 10 ** 6;

    address self;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        oracleRelayer = new MockOracleRelayer();
        orcl = new Feed(1 ether, true);

        setterRelayer = new MockSetterRelayer(address(oracleRelayer));
        calculator = new DirectRateCalculator(
          acceleration
        );

        rateSetter = new MockDirectRateSetter(address(orcl), address(oracleRelayer), address(calculator), address(setterRelayer));
        setterRelayer.modifyParameters("setter", address(rateSetter));

        self = address(this);
    }

    function test_setup() public {
        assertEq(calculator.authorities(address(this)), 1);
        assertEq(calculator.readers(address(this)), 1);
        assertEq(calculator.acc(), acceleration);
        assertEq(calculator.allReaderToggle(), 0);
    }
    function test_modifyParameters() public {
        calculator.modifyParameters("acc", 10 ** 3);
        calculator.modifyParameters("allReaderToggle", 1);

        assertEq(calculator.acc(), 10 ** 3);
        assertEq(calculator.allReaderToggle(), 1);
    }

    function test_null_acceleration() public {
        calculator.modifyParameters("acc", 0);
        assertEq(calculator.computeRate(1E18 + 10, 1E27, 1E27), 1E27);
    }

    function test_compose_decompose() public {
        assertEq(calculator.decomposeRate(1E27), 0);
        assertEq(calculator.decomposeRate(1E27 + 10), 10);
        assertEq(calculator.decomposeRate(1E27 - 1E4), -1E4);
        assertEq(calculator.decomposeRate(uint(-1)), -1000000000000000000000000001);
        assertEq(calculator.decomposeRate(1), -999999999999999999999999999000000000000000000000000000);

        assertEq(calculator.composeRate(int(0)), 1E27);
        assertEq(calculator.composeRate(int(-100)), 1E27 - 100);
        assertEq(calculator.composeRate(int(100)), 1E27 + 100);
        assertEq(calculator.composeRate(int(-1E27)), 5E26);
        assertEq(calculator.composeRate(int(uint(-1))), 1E27 - 1);
    }

    function test_compute_market_above_redemption_null_rate() public {
        assertEq(calculator.decomposeRate(1E27), 0);
        assertEq(calculator.getScaledProportional(1E18 + 1E5, 1E27), 100);
        assertEq(calculator.computeRate(1E18 + 1E5, 1E27, 1E27), 1E27 - 100);
    }
    function test_compute_market_below_redemption_null_rate() public {
        assertEq(calculator.decomposeRate(1E27), 0);
        assertEq(calculator.getScaledProportional(1E18 - 1E5, 1E27), 100);
        assertEq(calculator.computeRate(1E18 - 1E5, 1E27, 1E27), 1E27 + 100);
    }
    function test_compute_market_equals_redemption_null_rate() public {
        assertEq(calculator.decomposeRate(1E27), 0);
        assertEq(calculator.getScaledProportional(1E18, 1E27), 0);
        assertEq(calculator.computeRate(1E18, 1E27, 1E27), 1E27);
    }

    function test_compute_market_above_redemption_positive_rate() public {
        assertEq(calculator.decomposeRate(1E27 + 1E9), 1E9);
        assertEq(calculator.getScaledProportional(1E18 + 1E9, 1E27), 1000000);
        assertEq(calculator.computeRate(1E18 + 1E9, 1E27, 1E27 + 1E2), 999999999999999999999000100);
    }
    function test_compute_market_below_redemption_positive_rate() public {
        assertEq(calculator.decomposeRate(1E27 + 1E9), 1E9);
        assertEq(calculator.getScaledProportional(1E18 - 1E9, 1E27), 1000000);
        assertEq(calculator.computeRate(1E18 - 1E9, 1E27, 1E27 + 1E2), 1000000000000000000001000100);
    }
    function test_compute_market_equals_redemption_positive_rate() public {
        assertEq(calculator.decomposeRate(1E27), 0);
        assertEq(calculator.getScaledProportional(1E18, 1E27), 0);
        assertEq(calculator.computeRate(1E18, 1E27, 1E27 + 1E2), 1E27 + 1E2);
    }

    function test_compute_market_above_redemption_negative_rate() public {
        assertEq(calculator.decomposeRate(1E27 + 1E9), 1E9);
        assertEq(calculator.getScaledProportional(1E18 + 1E9, 1E27), 1000000);
        assertEq(calculator.computeRate(1E18 + 1E9, 1E27, 1E27 - 1E2), 999999999999999999998999900);
    }
    function test_compute_market_below_redemption_negative_rate() public {
        assertEq(calculator.decomposeRate(1E27 + 1E9), 1E9);
        assertEq(calculator.getScaledProportional(1E18 - 1E9, 1E27), 1000000);
        assertEq(calculator.computeRate(1E18 - 1E9, 1E27, 1E27 - 1E2), 1000000000000000000000999900);
    }
    function test_compute_market_equals_redemption_negative_rate() public {
        assertEq(calculator.decomposeRate(1E27), 0);
        assertEq(calculator.getScaledProportional(1E18, 1E27), 0);
        assertEq(calculator.computeRate(1E18, 1E27, 1E27 - 1E2), 1E27 - 1E2);
    }

    function testFail_compute_current_rate_zero() public {
        assertEq(calculator.computeRate(1E18 + 1E9, 1E27, 0), 1);
    }
    function test_compute_current_rate_max_uint() public {
        assertEq(calculator.computeRate(1E18 + 1E9, 1E27, uint(-1)), 499999999999999999999749999);
    }
}
