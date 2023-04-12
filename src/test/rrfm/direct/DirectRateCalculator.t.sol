pragma solidity 0.6.7;

import 'ds-test/test.sol';

import {DirectRateCalculator} from '../../calculator/DirectRateCalculator.sol';
import {MockSetterRelayer} from '../utils/mock/MockSetterRelayer.sol';
import {MockDirectRateSetter} from '../utils/mock/MockDirectRateSetter.sol';
import '../utils/mock/MockOracleRelayer.sol';

contract Feed {
  bytes32 public price;
  bool public validPrice;
  uint256 public lastUpdateTime;

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
    return uint256(price);
  }

  function getResultWithValidity() external view returns (uint256, bool) {
    return (uint256(price), validPrice);
  }
}

abstract contract Hevm {
  function warp(uint256) public virtual;
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
    hevm.warp(604_411_200);

    oracleRelayer = new MockOracleRelayer();
    orcl = new Feed(1 ether, true);

    setterRelayer = new MockSetterRelayer(address(oracleRelayer));
    calculator = new DirectRateCalculator(
          acceleration
        );

    rateSetter =
      new MockDirectRateSetter(address(orcl), address(oracleRelayer), address(calculator), address(setterRelayer));
    setterRelayer.modifyParameters('setter', address(rateSetter));

    self = address(this);
  }

  function test_setup() public {
    assertEq(calculator.authorities(address(this)), 1);
    assertEq(calculator.readers(address(this)), 1);
    assertEq(calculator.acc(), acceleration);
    assertEq(calculator.allReaderToggle(), 0);
  }

  function test_modifyParameters() public {
    calculator.modifyParameters('acc', 10 ** 3);
    calculator.modifyParameters('allReaderToggle', 1);

    assertEq(calculator.acc(), 10 ** 3);
    assertEq(calculator.allReaderToggle(), 1);
  }

  function test_null_acceleration() public {
    calculator.modifyParameters('acc', 0);
    assertEq(calculator.computeRate(1e18 + 10, 1e27, 1e27), 1e27);
  }

  function test_compose_decompose() public {
    assertEq(calculator.decomposeRate(1e27), 0);
    assertEq(calculator.decomposeRate(1e27 + 10), 10);
    assertEq(calculator.decomposeRate(1e27 - 1e4), -1e4);
    assertEq(calculator.decomposeRate(uint256(-1)), -1_000_000_000_000_000_000_000_000_001);
    assertEq(calculator.decomposeRate(1), -999_999_999_999_999_999_999_999_999_000_000_000_000_000_000_000_000_000);

    assertEq(calculator.composeRate(int256(0)), 1e27);
    assertEq(calculator.composeRate(int256(-100)), 1e27 - 100);
    assertEq(calculator.composeRate(int256(100)), 1e27 + 100);
    assertEq(calculator.composeRate(int256(-1e27)), 5e26);
    assertEq(calculator.composeRate(int256(uint256(-1))), 1e27 - 1);
  }

  function test_compute_market_above_redemption_null_rate() public {
    assertEq(calculator.decomposeRate(1e27), 0);
    assertEq(calculator.getScaledProportional(1e18 + 1e5, 1e27), 100);
    assertEq(calculator.computeRate(1e18 + 1e5, 1e27, 1e27), 1e27 - 100);
  }

  function test_compute_market_below_redemption_null_rate() public {
    assertEq(calculator.decomposeRate(1e27), 0);
    assertEq(calculator.getScaledProportional(1e18 - 1e5, 1e27), 100);
    assertEq(calculator.computeRate(1e18 - 1e5, 1e27, 1e27), 1e27 + 100);
  }

  function test_compute_market_equals_redemption_null_rate() public {
    assertEq(calculator.decomposeRate(1e27), 0);
    assertEq(calculator.getScaledProportional(1e18, 1e27), 0);
    assertEq(calculator.computeRate(1e18, 1e27, 1e27), 1e27);
  }

  function test_compute_market_above_redemption_positive_rate() public {
    assertEq(calculator.decomposeRate(1e27 + 1e9), 1e9);
    assertEq(calculator.getScaledProportional(1e18 + 1e9, 1e27), 1_000_000);
    assertEq(calculator.computeRate(1e18 + 1e9, 1e27, 1e27 + 1e2), 999_999_999_999_999_999_999_000_100);
  }

  function test_compute_market_below_redemption_positive_rate() public {
    assertEq(calculator.decomposeRate(1e27 + 1e9), 1e9);
    assertEq(calculator.getScaledProportional(1e18 - 1e9, 1e27), 1_000_000);
    assertEq(calculator.computeRate(1e18 - 1e9, 1e27, 1e27 + 1e2), 1_000_000_000_000_000_000_001_000_100);
  }

  function test_compute_market_equals_redemption_positive_rate() public {
    assertEq(calculator.decomposeRate(1e27), 0);
    assertEq(calculator.getScaledProportional(1e18, 1e27), 0);
    assertEq(calculator.computeRate(1e18, 1e27, 1e27 + 1e2), 1e27 + 1e2);
  }

  function test_compute_market_above_redemption_negative_rate() public {
    assertEq(calculator.decomposeRate(1e27 + 1e9), 1e9);
    assertEq(calculator.getScaledProportional(1e18 + 1e9, 1e27), 1_000_000);
    assertEq(calculator.computeRate(1e18 + 1e9, 1e27, 1e27 - 1e2), 999_999_999_999_999_999_998_999_900);
  }

  function test_compute_market_below_redemption_negative_rate() public {
    assertEq(calculator.decomposeRate(1e27 + 1e9), 1e9);
    assertEq(calculator.getScaledProportional(1e18 - 1e9, 1e27), 1_000_000);
    assertEq(calculator.computeRate(1e18 - 1e9, 1e27, 1e27 - 1e2), 1_000_000_000_000_000_000_000_999_900);
  }

  function test_compute_market_equals_redemption_negative_rate() public {
    assertEq(calculator.decomposeRate(1e27), 0);
    assertEq(calculator.getScaledProportional(1e18, 1e27), 0);
    assertEq(calculator.computeRate(1e18, 1e27, 1e27 - 1e2), 1e27 - 1e2);
  }

  function testFail_compute_current_rate_zero() public {
    assertEq(calculator.computeRate(1e18 + 1e9, 1e27, 0), 1);
  }

  function test_compute_current_rate_max_uint() public {
    assertEq(calculator.computeRate(1e18 + 1e9, 1e27, uint256(-1)), 499_999_999_999_999_999_999_749_999);
  }
}
